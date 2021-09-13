#!/bin/bash
set -o errexit
set -o pipefail
set -o nounset
export CLUSTER_NAME=anthos-aws-v2
export OUTPUT_FILE=aws-resources.sh
source $OUTPUT_FILE


gcloud alpha container aws clusters create $CLUSTER_NAME \
  --aws-region=$AWS_REGION --location=$GCP_REGION \
  --subnet-ids=$CONTROL_PLANE_SUBNET_1,$CONTROL_PLANE_SUBNET_2,$CONTROL_PLANE_SUBNET_3 \
  --pod-address-cidr-blocks=10.1.0.0/16 \
  --service-address-cidr-blocks=10.2.0.0/16 \
  --vpc-id=$VPC_ID \
  --service-load-balancer-subnet-ids=$PUBLIC_SERVICE_SUBNET \
  --cluster-version=1.19.10-gke.1000 \
  --database-encryption-kms-key-arn=$DB_KMS_KEY_ARN \
  --iam-instance-profile=$CONTROL_PLANE_PROFILE \
  --instance-type=t3.medium \
  --ssh-ec2-key-pair=$SSH_KEY_PAIR_NAME \
  --main-volume-size=10 \
  --root-volume-size=10 \
  --role-arn=$API_ROLE_ARN \
  --role-session-name=ROLE_SESSION_NAME
PROJECT_ID="$(gcloud config get-value project)"
gcloud services enable gkeconnect.googleapis.com MEMBER="serviceAccount:$PROJECT_ID.svc.id.goog[gke-system/gke-multicloud-agent]"
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="$MEMBER" \
    --role="roles/gkehub.connect"
