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


# Functions
is_deployment_ready() { 
    kubectl --kubeconfig $1 -n $2 get deploy $3 &> /dev/null
    export exit_code=$?
    while [ ! " ${exit_code} " -eq 0 ]
        do 
            sleep 5
            echo -e "Waiting for deployment $3 in cluster $1 to be created..."
            kubectl --kubeconfig $1 -n $2 get deploy $3 &> /dev/null
            export exit_code=$?
        done
    echo -e "Deployment $3 in cluster $1 created."

    # Once deployment is created, check for deployment status.availableReplicas is greater than 0
    export availableReplicas=$(kubectl --kubeconfig $1 -n $2 get deploy $3 -o json | jq -r '.status.availableReplicas')
    while [[ " ${availableReplicas} " == " null " ]]
        do 
            sleep 5
            echo -e "Waiting for deployment $3 in cluster $1 to become ready..."
            export availableReplicas=$(kubectl --kubeconfig $1 -n $2 get deploy $3 -o json | jq -r '.status.availableReplicas')
        done
    
    echo -e "$3 in cluster $1 is ready with replicas ${availableReplicas}."
    # Returned value is a bash return status as opposed to replica count. 
    #return ${availableReplicas}
}



# Get kubeconfig file
gsutil cp -r gs://$PROJECT_ID/kubeconfig/kubeconfig_$EKS_CLUSTER kubeconfig_$EKS_CLUSTER

# Get ConfigManagement Operator YAML
gsutil cp gs://config-management-release/released/latest/config-management-operator.yaml config-management-operator_$EKS_CLUSTER.yaml

# Get the SSH private key file
gsutil cp gs://$PROJECT_ID/ssh-keys/ssh-key-private ssh-key-private_$EKS_CLUSTER

# Prep ACM yaml
#sed -e s/CLUSTER_NAME/${EKS_CLUSTER}/g -e s~REPO_URL~${REPO_URL}~g ./configmanagement.yaml_tmpl > configmanagement_$EKS_CLUSTER.yaml 
#cat configmanagement.yaml
cat <<EOF > configmanagement_$EKS_CLUSTER.yaml
apiVersion: configmanagement.gke.io/v1
kind: ConfigManagement
metadata:
  name: config-management
spec:
  # clusterName is required and must be unique among all managed clusters
  clusterName: $EKS_CLUSTER
  policyController:
    enabled: true
    templateLibraryInstalled: true
  git:
    syncRepo: $REPO_URL
    syncBranch: $SYNC_BRANCH
    secretType: none
    policyDir: foo-corp
EOF

# Deploy to cluster
kubectl --kubeconfig=kubeconfig_$EKS_CLUSTER apply -f config-management-operator_$EKS_CLUSTER.yaml
# Create git-creds secret
kubectl --kubeconfig=kubeconfig_$EKS_CLUSTER create secret generic git-creds \
--namespace=config-management-system \
--from-file=ssh=ssh-key-private_$EKS_CLUSTER

# Deploy configmanagement
kubectl --kubeconfig=kubeconfig_$EKS_CLUSTER apply -f configmanagement_$EKS_CLUSTER.yaml

# Gatekeeper takes time to start, check that gatekeeper controller is ready
#is_deployment_ready kubeconfig_${EKS_CLUSTER} gatekeeper-system gatekeeper-controller-manager
