#!/bin/bash

. utils.sh

min_helm_version="3.1"

if [[ "$PLATFORM" == "openshift" ]]; then
  IMAGE_REPOSITORY="${IMAGE_REPOSITORY:-registry.connect.redhat.com/cyberark/conjur}"
  IMAGE_TAG="${IMAGE_TAG:-latest}"
  NGINX_REPOSITORY="${NGINX_REPOSITORY:-registry.connect.redhat.com/cyberark/conjur-nginx}"
  NGINX_TAG="${NGINX_TAG:-latest}"
  POSTGRES_REPOSITORY="${POSTGRES_REPOSITORY:-registry.redhat.io/rhscl/postgresql-10-rhel7}"
  POSTGRES_TAG="${POSTGRES_TAG:-latest}"
  POSTGRES_PV_CREATE="${STORAGE_CLASS:-false}"
  OPENSHIFT_ENABLED="${OPENSHIFT_ENABLED:-true}"
fi

# Confirm that 'helm' binary is installed.
if ! command -v helm &> /dev/null; then
  echo "helm binary not found. See https://helm.sh/docs/intro/install/"
  echo "for installation instructions."
  exit 1
fi

# Check version of 'helm' binary.
helm_version="$(helm version --template {{.Version}} | sed 's/^v//')"
if ! meets_min_version $helm_version $min_helm_version; then
  echo "helm version $helm_version is invalid. Version must be $min_helm_version or newer"
  exit 1
fi

# Create the namespace for the Conjur cluster if necessary
if has_namespace "$CONJUR_NAMESPACE"; then
  echo "Namespace '$CONJUR_NAMESPACE' exists, not going to create it."
else
  kubectl create ns "$CONJUR_NAMESPACE"
fi

# Check if the Conjur cluster release has already been installed. If so, run
# Helm upgrade. Otherwise, do a Helm install of the Conjur cluster.
if [ "$(helm list -q -n $CONJUR_NAMESPACE | grep "^$HELM_RELEASE$")" = "$HELM_RELEASE" ]; then
  echo "Helm upgrading existing Conjur cluster. Waiting for upgrade to complete."
  if [[ "$PLATFORM" == "openshift" ]]; then
  helm upgrade \
      -n "$CONJUR_NAMESPACE" \
      --set account.name="$CONJUR_ACCOUNT" \
      --set account.create="true" \
      --set authenticators="authn\,authn-k8s/$AUTHENTICATOR_ID" \
      --set logLevel="$CONJUR_LOG_LEVEL" \
      --set service.external.enabled="$CONJUR_LOADBALANCER_SVCS" \
      --set image.repository="$IMAGE_REPOSITORY" \
      --set image.tag="$IMAGE_TAG" \
      --set nginx.image.repository="$NGINX_REPOSITORY" \
      --set nginx.image.tag="$NGINX_TAG" \
      --set postgres.image.repository="$POSTGRES_REPOSITORY" \
      --set postgres.image.tag="$POSTGRES_TAG" \
      --set postgres.persistentVolume.create="$POSTGRES_PV_CREATE" \
      --set openshift.enabled="true" \
      --reuse-values \
      --wait \
      --timeout 300s \
      "$HELM_RELEASE" \
      "../../conjur-oss"
  else
  helm upgrade \
      -n "$CONJUR_NAMESPACE" \
      --set account.name="$CONJUR_ACCOUNT" \
      --set account.create="true" \
      --set authenticators="authn\,authn-k8s/$AUTHENTICATOR_ID" \
      --set logLevel="$CONJUR_LOG_LEVEL" \
      --set service.external.enabled="$CONJUR_LOADBALANCER_SVCS" \
      --reuse-values \
      --wait \
      --timeout 300s \
      "$HELM_RELEASE" \
      "../../conjur-oss"
  fi
else
  # Helm install a Conjur cluster and create a Conjur account
  echo "Helm installing a Conjur cluster. Waiting for install to complete."
  data_key="$(docker run --rm cyberark/conjur data-key generate)"
  if [[ "$PLATFORM" == "openshift" ]]; then
  helm install \
      -n "$CONJUR_NAMESPACE" \
      --set dataKey="$data_key" \
      --set account.name="$CONJUR_ACCOUNT" \
      --set account.create="true" \
      --set authenticators="authn\,authn-k8s/$AUTHENTICATOR_ID" \
      --set logLevel="$CONJUR_LOG_LEVEL" \
      --set service.external.enabled="$CONJUR_LOADBALANCER_SVCS" \
      --set image.repository="$IMAGE_REPOSITORY" \
      --set image.tag="$IMAGE_TAG" \
      --set nginx.image.repository="$NGINX_REPOSITORY" \
      --set nginx.image.tag="$NGINX_TAG" \
      --set postgres.image.repository="$POSTGRES_REPOSITORY" \
      --set postgres.image.tag="$POSTGRES_TAG" \
      --set postgres.persistentVolume.create="$POSTGRES_PV_CREATE" \
      --set openshift.enabled="true" \
      --wait \
      --timeout 300s \
      "$HELM_RELEASE" \
      "../../conjur-oss"
  else
 helm install \
      -n "$CONJUR_NAMESPACE" \
      --set dataKey="$data_key" \
      --set account.name="$CONJUR_ACCOUNT" \
      --set account.create="true" \
      --set authenticators="authn\,authn-k8s/$AUTHENTICATOR_ID" \
      --set logLevel="$CONJUR_LOG_LEVEL" \
      --set service.external.enabled="$CONJUR_LOADBALANCER_SVCS" \
      --wait \
      --timeout 300s \
      "$HELM_RELEASE" \
      "../../conjur-oss"
  fi
fi
