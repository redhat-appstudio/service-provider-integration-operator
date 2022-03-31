#!/bin/bash

####
# Script to setup 2 minikube clusters where one is running the operator, vault and the other runs oauth service
####

SCRIPT_DIR=$(dirname "$0")

# the shared secret set in the configuration of SPI in both clusters
SHARED_SECRET="kachny"

# change the directory so that we can run make
cd "$SCRIPT_DIR/../.." || exit 1

# we'll be starting 2 minikubes on the same network

function defineVirtualNetwork {
  local NETWORK_FILE
  local INET_IFACE

  NETWORK_FILE=$(mktemp)

  # figure out which interface connects to the internet
  INET_IFACE=$(ip route get "$(getent ahosts "google.com" | awk '{print $1; exit}')" | grep -Po '(?<=(dev ))(\S+)')

  sh -c "cat > $NETWORK_FILE << END
  <network>
    <name>minikubes</name>
    <uuid>33361b46-1581-acb7-1643-85a412626e70</uuid>
    <forward dev='$INET_IFACE'/>
    <bridge name='vminikubes' stp='on' forwardDelay='0' />
    <ip address='192.168.139.1' netmask='255.255.255.0'>
      <dhcp>
        <range start='192.168.139.128' end='192.168.139.254' />
      </dhcp>
    </ip>
  </network>
  END
  "

  sudo virsh net-define "$NETWORK_FILE"
  rm "$NETWORK_FILE"
}

function startMinikubes {
  minikube start --profile=minikube-a --network=minikubes
  minikube addons enable ingress -p minikube-a
  minikube start --profile=minikube-b --network=minikubes
  minikube addons enable ingress -p minikube-b
}

function prepareMinikubeA {
  local SECRET_NAME
  local SPI_CONFIG

  # install operator and vault into minikube-a (i.e. install everything and just stop the oauth service)
  minikube profile minikube-a
  kubectl config use-context minikube-a
  make install deploy_minikube
  kubectl -n spi-system scale deployment spi-oauth-service --replicas=0

  # configure the shared secret in the configuration
  SECRET_NAME=$(kubectl -n spi-system get secret -l app.kubernetes.io/part-of=service-provider-integration-operator -o name)
  SPI_CONFIG=$(kubectl -n spi-system get "$SECRET_NAME" -o jsonpath="{.data['config\.yaml']}" | base64 -d)
  SPI_CONFIG=$(echo "$SPI_CONFIG" | yq ".sharedSecret = \"$SHARED_SECRET\"" | base64 -w0)
  kubectl -n spi-system patch "$SECRET_NAME" -p "{\"data\": {\"config.yaml\": \"$SPI_CONFIG\"}}"
  kubectl -n spi-system scale deployment spi-controller-manager --replicas=0
  kubectl -n spi-system scale deployment spi-controller-manager --replicas=1

  # create an ingress for vault endpoint so that the oauth service from the other cluster can reach it
  # (executed in a subshell so that we can do variable expansion in the heredoc)
  sh -c "kubectl apply -f - << END
  apiVersion: networking.k8s.io/v1
  kind: Ingress
  metadata:
    name: vault-ingress
    namespace: spi-system
  spec:
    rules:
    - host: vault.$(minikube ip --profile minikube-a).nip.io
      http:
        paths:
        - backend:
            service:
              name: spi-vault
              port:
                number: 8200
          path: /
          pathType: ImplementationSpecific
  END
  "
}

function prepareMinikubeB {
  local KDIR
  local TOKEN

  # install oauth service into minikube-b
  minikube profile minikube-b
  kubectl config use-context minikube-b

  # we need to build our own kustomization for this...
  KDIR=$(mktemp -d)
  cp -r .tmp/deployment_minikube/oauth "$KDIR"
  cp -r .tmp/deployment_minikube/namespace "$KDIR"
  cp -r .tmp/deployment_minikube/k8s "$KDIR"
  cd "$KDIR/k8s" || exit 1

  # set the shared secret to the same value as in cluster a
  yq -y ".sharedSecret = \"$SHARED_SECRET\" | .vaultHost = \"https://vault.$(minikube ip -p minikube-a).nip.io\" | .baseUrl = \"https://spi.$(minikube ip -p minikube-b).nip.io\"" < config.yaml > tmp.yaml
  mv tmp.yaml config.yaml

  # read the token of the OAuth service from minikube-a cluster
  kubectl config use-context minikube-a
  API_SERVER_A=$(kubectl config view -o jsonpath="{.clusters[?(@.name==\"minikube-a\")].cluster.server}")
  TOKEN=$(kubectl -n spi-system get secret "$(kubectl -n spi-system get serviceaccount spi-oauth-sa -o yaml | yq -r '.secrets[0].name')" -o json | jq -r '.data.token' | base64 -d)
  sh -c "cat > token.yaml << END
apiVersion: v1
kind: Secret
metadata:
  name:
    vault-token
data:
  vault-token: \"$(echo "$TOKEN" | base64 -w0)\"
END
"

  # modify the deployment to mount the service account token from the minikube-a cluster to give us access to the vault
  # in minikube-b cluster
  yq -y . < ../oauth/deployment.yaml | \
  yq -y '.spec.template.spec.containers[0].volumeMounts += [{"mountPath": "/tmp/vault-access", "name": "vault-access", "readOnly": true}]' | \
  yq -y '.spec.template.spec.volumes += [{"name": "vault-access", "secret": {"secretName": "vault-token", "items": [{"key": "vault-token", "path": "vault-token"}]}}]' | \
  yq -y '.spec.template.spec.containers[0].env = [{"name": "API_SERVER", "value": "'"$API_SERVER_A"'"}, {"name": "SA_TOKEN_PATH", "value": "/tmp/vault-access/vault-token"}]' \
  > tmp.yaml
  mv tmp.yaml ../oauth/deployment.yaml

  # modify the ingress with the IP address of our minikube-b cluster
  yq -y ".spec.rules[0].host = \"spi.$(minikube ip -p minikube-b).nip.io\"" < ingress.yaml > tmp.yaml
  mv tmp.yaml ingress.yaml

  # modify the kustomization to only deploy oauth service and our additions
  yq -y '.resources = ["../namespace", "../oauth", "ingress.yaml", "token.yaml"]' < kustomization.yaml > tmp.yaml
  mv tmp.yaml kustomization.yaml

  # and run kustomize
  kubectl config use-context minikube-b
  kustomize edit set image quay.io/redhat-appstudio/service-provider-integration-operator="${SPIO_IMG}"
  kustomize edit set image quay.io/redhat-appstudio/service-provider-integration-oauth="${SPIS_IMG}"
  kustomize build . | kubectl apply -f -
}

defineVirtualNetwork
startMinikubes
prepareMinikubeA
prepareMinikubeB
