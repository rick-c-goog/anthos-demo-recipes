#!/usr/bin/env bash
# Copyright 2020 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

mkdir -p ${PWD}/lm
WORKDIR=${PWD}/lm
cd ${WORKDIR}

# Get kubeconfig file
gsutil cp gs://${PROJECT_ID}/kubeconfig/kubeconfig_${EKS_CLUSTER} ${WORKDIR}/kubeconfig_${EKS_CLUSTER}

# Get the cloudops GSA
gsutil cp gs://${PROJECT_ID}/cloudopsgsa/cloud_ops_sa_key.json ${WORKDIR}/

# Get the logging monitoring resources
echo "Clone lm repo"
git clone https://github.com/GoogleCloudPlatform/anthos-samples

# Create secret for cloudops
echo "Create cloudops secret yaml"
kubectl create secret generic google-cloud-credentials \
    -n kube-system \
    --from-file=credentials.json=${WORKDIR}/cloud_ops_sa_key.json \
    --dry-run \
    -o yaml \
    > ${WORKDIR}/google-cloud-credentials.yaml

# Install logging/monitoring resources
cd ${WORKDIR}/anthos-samples/attached-logging-monitoring

CLUSTER_KUBECONFIG=${WORKDIR}/kubeconfig_${EKS_CLUSTER}

echo "Apply cloudops secret"
kubectl --kubeconfig ${CLUSTER_KUBECONFIG} apply -f ${WORKDIR}/google-cloud-credentials.yaml --overwrite

echo "Apply logging aggregator and forwarder"
sed -e "s|\[PROJECT[_&$]ID\]|${PROJECT_ID}|g" \
    -e "s|.*k8s_cluster_name.*|      k8s_cluster_name ${CLUSTER}|" \
    -e "s|.*k8s_cluster_location.*|      k8s_cluster_location global|" \
    -e "s|# storageClassName: gp2|storageClassName: gp2|g" \
    logging/aggregator.yaml \
    > aggregator_${EKS_CLUSTER}.yaml
kubectl --kubeconfig ${CLUSTER_KUBECONFIG} apply -f aggregator_${EKS_CLUSTER}.yaml
kubectl --kubeconfig ${CLUSTER_KUBECONFIG} apply -f logging/forwarder.yaml

echo "Apply monitoring prometheus and configuration"
sed -e "s|\[PROJECT[_&$]ID\]|${PROJECT_ID}|g" \
    -e "s|\[CLUSTER[_&$]NAME\]|${EKS_CLUSTER}|g" \
    -e "s|\[CLUSTER[_&$]LOCATION\]|global|g" \
    -e "s|# storageClassName: gp2|storageClassName: gp2|g" \
    monitoring/prometheus.yaml \
    > prometheus_${EKS_CLUSTER}.yaml
kubectl --kubeconfig ${CLUSTER_KUBECONFIG} apply -f prometheus_${EKS_CLUSTER}.yaml
kubectl --kubeconfig ${CLUSTER_KUBECONFIG} apply -f monitoring/server-configmap.yaml
kubectl --kubeconfig ${CLUSTER_KUBECONFIG} apply -f monitoring/sidecar-configmap.yaml