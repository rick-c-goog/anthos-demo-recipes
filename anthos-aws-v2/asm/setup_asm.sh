#!/bin/bash
# Save an environment variable to the output file.
gcloud components install kpt

CLUSTER_NAME=anthos-aws-v2
gcloud container hub memberships get-credentials $CLUSTER_NAME
curl -LO https://storage.googleapis.com/gke-release/asm/istio-1.10.4-asm.6-linux-amd64.tar.gz
tar xzf istio-1.10.4-asm.6-linux-amd64.tar.gz
cd istio-1.10.4-asm.6

bin/istioctl install \
  -f manifests/profiles/asm-multicloud.yaml \
  --set revision=asm-1104-6


