#!/bin/bash

#set -x
set -e

NAMESPACE=${NAMESPACE:-spi-system}
SECRET_NAME=spi-vault-keys
POD_NAME=${POD_NAME:-spi-vault-0}
KEYS_FILE=${KEYS_FILE:-$( mktemp )}
ROOT_TOKEN=""

function vaultExec() {
  COMMAND=${1}
  kubectl exec ${POD_NAME} -n ${NAMESPACE} -- sh -c "${COMMAND}" 2> /dev/null
}

function init() {
  if [ "$( isInitialized )" == "false" ]; then
    vaultExec "vault operator init" > "${KEYS_FILE}"
    echo "Keys written at ${KEYS_FILE}"
  else
    echo "Already initialized"
  fi
}

function isInitialized() {
  INITIALIZED=$( vaultExec "vault status -format=yaml | grep initialized" )
  if [ -z "${INITIALIZED}" ]; then
    echo "failed to obtain initialized status"
    exit 1
  fi
  echo "${INITIALIZED}" | awk '{split($0,a,": "); print a[2]}'
}

function isSealed() {
  SEALED=$( vaultExec "vault status -format=yaml | grep sealed" )
  echo "${SEALED}" | awk '{split($0,a,": "); print a[2]}'
}

function secret() {
  if [ ! -s "${KEYS_FILE}" ]; then
    return
  fi

  if kubectl get secret ${SECRET_NAME} -n ${NAMESPACE}; then
    echo "Secret 5{SECRET_NAME} already exists. Deleting ..."
    kubectl delete secret ${SECRET_NAME} -n ${NAMESPACE}
  fi

  COMMAND="kubectl create secret generic ${SECRET_NAME} -n ${NAMESPACE}"
  KEYI=1
  # shellcheck disable=SC2013
  for KEY in $( grep "Unseal Key" "${KEYS_FILE}" | awk '{split($0,a,": "); print a[2]}'); do
    COMMAND="${COMMAND} --from-literal=key${KEYI}=${KEY}"
    (( KEYI++ ))
  done

  ${COMMAND}
}

function unseal() {
  KEYI=1
  until [ "$( isSealed )" == "false" ]; do
    echo "unsealing ..."
    KEY=$( kubectl get secret ${SECRET_NAME} -n ${NAMESPACE} --template="{{.data.key${KEYI}}}" | base64 --decode )
    if [ -z "${KEY}" ]; then
      echo "failed to unseal"
      exit 1
    fi
    vaultExec "vault operator unseal ${KEY}"
    (( KEYI++ ))
  done
  echo "unsealed"
}

function login() {
  vaultExec "vault login ${ROOT_TOKEN} > /dev/null"
}

function ensureRootToken() {
  if [ -s "${KEYS_FILE}" ]; then
    ROOT_TOKEN=$( grep "Root Token" "${KEYS_FILE}" | awk '{split($0,a,": "); print a[2]}' )
  else
    generateRootToken
  fi
}

function generateRootToken() {
  echo "generating root token ..."

  vaultExec "vault operator generate-root -cancel" > /dev/null
  INIT=$( vaultExec "vault operator generate-root -init -format=yaml" )
  NONCE=$( echo "${INIT}" | grep "nonce:" | awk '{split($0,a,": "); print a[2]}' )
  OTP=$( echo "${INIT}" | grep "otp:" | awk '{split($0,a,": "); print a[2]}' )

  KEYI=1
  COMPLETE="false"
  until [ "${COMPLETE}" == "true" ]; do
    KEY=$( kubectl get secret ${SECRET_NAME} -n ${NAMESPACE} --template="{{.data.key${KEYI}}}" | base64 --decode )
    if [ -z "${KEY}" ]; then
      echo "failed to generate token"
      exit 1
    fi
    GENERATE_OUTPUT=$( vaultExec "echo ${KEY} | vault operator generate-root -nonce=${NONCE} -format=yaml -" )
    COMPLETE=$( echo "${GENERATE_OUTPUT}" | grep "complete:" | awk '{split($0,a,": "); print a[2]}' )
    if [ "${COMPLETE}" == "true" ]; then
      ENCODED_TOKEN=$( echo "${GENERATE_OUTPUT}" | grep "encoded_token" | awk '{split($0,a,": "); print a[2]}' )
      ROOT_TOKEN=$( vaultExec "vault operator generate-root \
        -decode=${ENCODED_TOKEN} \
        -otp=${OTP} -format=yaml" \
        | awk '{split($0,a,": "); print a[2]}' )
    fi
    (( KEYI++ ))
  done
}

function audit() {
  if ! vaultExec "vault audit list | grep -q file"; then
    echo "enabling audit log ..."
    vaultExec "vault audit enable file file_path=stdout"
  fi
}

function auth() {
  vaultExec "vault policy write spi /vault/userconfig/scripts/spi_policy.hcl"
  k8sAuth
  approleAuth
}

function k8sAuth() {
  if ! vaultExec "vault auth list | grep -q kubernetes" ; then
    echo "setup kubernetes authentication ..."
    vaultExec "vault auth enable kubernetes"
  fi
  vaultExec "vault write auth/kubernetes/role/spi-controller-manager \
        bound_service_account_names=spi-controller-manager \
        bound_service_account_namespaces=spi-system \
        policies=spi"
  vaultExec "vault write auth/kubernetes/role/spi-oauth \
          bound_service_account_names=spi-oauth-sa \
          bound_service_account_namespaces=spi-system \
          policies=spi"
  # shellcheck disable=SC2016
  vaultExec 'vault write auth/kubernetes/config \
        kubernetes_host=https://$KUBERNETES_SERVICE_HOST:$KUBERNETES_SERVICE_PORT'
}

function approleAuth() {
  if ! vaultExec "vault auth list | grep -q approle" ; then
    echo "setup approle authentication ..."
    vaultExec "vault auth enable approle"
  fi

  if [ ! -d ".tmp" ]; then mkdir -p .tmp; fi
  SECRET_FILE=$( realpath .tmp/approle_secret.yaml )

  function approleSet() {
    vaultExec "vault write auth/approle/role/${1} token_policies=spi"
    ROLE_ID=$( vaultExec "vault read auth/approle/role/${1}/role-id --format=json" | jq -r '.data.role_id' )
    SECRET_ID=$( vaultExec "vault write -force auth/approle/role/${1}/secret-id --format=json" | jq -r '.data.secret_id' )
    echo "---" >> ${SECRET_FILE}
    kubectl create secret generic vault-approle-${1} \
      --from-literal=role_id=${ROLE_ID} --from-literal=secret_id=${SECRET_ID} \
      --dry-run=client -o yaml >> ${SECRET_FILE}
  }

  if [ -f ${SECRET_FILE} ]; then rm ${SECRET_FILE}; fi
  touch ${SECRET_FILE}
  approleSet spi-operator
  approleSet spi-oauth

  cat << EOF

secret yaml with Vault credentials prepared
make sure your kubectl context targets cluster with SPI deployment and create the secret using (check spi namespace):

  $ kubectl apply -f ${SECRET_FILE} -n spi-system

EOF
}

function spiSecretEngine() {
  if ! vaultExec "vault secrets list | grep -q spi" ; then
    echo "creating SPI secret engine ..."
    vaultExec "vault secrets enable -path=spi kv-v2"
  fi
}

function restart() {
  echo "restarting vault pod '${POD_NAME}' ..."
  kubectl delete pod ${POD_NAME} -n ${NAMESPACE} > /dev/null
}

until [ "$(kubectl get pod ${POD_NAME} -n ${NAMESPACE} -o jsonpath='{.status.phase}')" == "Running" ]; do
   sleep 5
   echo "Waiting for Vault pod to be ready."
done

sleep 5

init
secret
unseal
ensureRootToken
login
audit
spiSecretEngine
auth
restart
