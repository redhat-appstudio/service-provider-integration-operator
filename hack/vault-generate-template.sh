#!/bin/sh

# Openshift template
echo "# This file is generated by './hack/vault-generate-template.sh'. Please do not edit this directly." > config/vault/deployment_os.yaml
helm template vault hashicorp/vault --set "global.openshift=true" --values hack/vault-helm-values.yaml --namespace system >> config/vault/deployment_os.yaml

# Kubernetes template
echo "# This file is generated by './hack/vault-generate-template.sh'. Please do not edit this directly." > config/vault/deployment_k8s.yaml
helm template vault hashicorp/vault --values hack/vault-helm-values.yaml --namespace system >> config/vault/deployment_k8s.yaml
