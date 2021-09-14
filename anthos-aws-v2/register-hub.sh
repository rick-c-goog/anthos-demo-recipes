#!/bin/bash
set -o errexit
set -o pipefail
set -o nounset

source ./aws-resources.sh
ADMIN_KUBECONFIG=$HOME/admin_kubeconfig
gcloud alpha container aws clusters get-kubeconfig $CLUSTER_NAME \
      --location=$GCP_REGION --output-file=$ADMIN_KUBECONFIG
gcloud alpha container aws clusters get-credentials $CLUSTER_NAME \
      --location=$GCP_REGION


ISSUER_URI=$(gcloud alpha container aws clusters describe $CLUSTER_NAME \
  --location=$GCP_REGION \
  --format='value(workloadIdentityConfig.issuerUri)')
CURRENT_CONTEXT=$(kubectl config current-context \
  --kubeconfig=$ADMIN_KUBECONFIG)
gcloud services enable gkehub.googleapis.com
HTTPS_PROXY=http://127.0.0.1:8118  gcloud container hub memberships register $CLUSTER_NAME \
  --context=$CURRENT_CONTEXT \
  --kubeconfig=$ADMIN_KUBECONFIG \
  --enable-workload-identity \
  --public-issuer-url=$ISSUER_URI


