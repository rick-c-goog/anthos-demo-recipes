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

#
echo "Copying EKS clusters' kubeconfig files to GCS..."
gsutil cp -r kubeconfig_$EKS gs://$PROJECT_ID/kubeconfig/kubeconfig_$EKS

export AWS_AUTHENTICATOR_INSTALLED=`which aws-iam-authenticator`
if [[ ${AWS_AUTHENTICATOR_INSTALLED} ]]; then
  title_no_wait "aws-iam-authenticator is already installed."
else
  curl -o $HOME/.local/bin/aws-iam-authenticator https://amazon-eks.s3.us-west-2.amazonaws.com/1.19.6/2021-01-05/bin/linux/amd64/aws-iam-authenticator
  chmod +x /$HOME/.local/bin/aws-iam-authenticator
  aws-iam-authenticator version
fi

export EKSCTL_INSTALLED=`which eksctl`
if [[ ${EKSCTL_INSTALLED} ]]; then
  title_no_wait "eksctl is already installed."
else
  #curl -o $HOME/.local/bin/eksctl https://amazon-eks.s3.us-west-2.amazonaws.com/1.19.6/2021-01-05/bin/linux/amd64/aws-iam-authenticator
  curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C .
  mv eksctl /$HOME/.local/bin/
  chmod +x /$HOME/.local/bin/eksctl
  #aws-iam-authenticator version
fi

#
#SECRET_NAME=$(kubectl --kubeconfig=kubeconfig_$EKS get serviceaccount gke-hub-ksa -o jsonpath='{$.secrets[0].name}')
#kubectl --kubeconfig=kubeconfig_$EKS get secret ${SECRET_NAME} -o jsonpath='{$.data.token}' | base64 -d > $EKS-ksa-token.txt
eksctl utils associate-iam-oidc-provider --cluster $EKS --approve
# Upload the ksa-token to GCS bucket
#gsutil cp -r $EKS-ksa-token.txt gs://$PROJECT_ID/kubeconfig/$EKS-ksa-token.txt

# Get Anthos Hub GSA credentials file
#gsutil cp -r gs://${PROJECT_ID}/hubgsa/gke_hub_sa_key.json .

# Register the EKS cluster
#gcloud container hub memberships register ${EKS} --project=${PROJECT_ID} --context=eks_${EKS} --kubeconfig=kubeconfig_${EKS} --service-account-key-file=gke_hub_sa_key.json
gcloud container hub memberships register ${EKS} --project=${PROJECT_ID} --context=eks_${EKS} --kubeconfig=kubeconfig_${EKS}  --enable-workload-identity   --public-issuer-url=${OIDC_URL}
# Add labels to the registered cluster
gcloud container hub memberships update ${EKS} --update-labels environ=${ENV},infra=aws

gcloud container hub memberships get-credentials ${EKS}