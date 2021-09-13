set -o errexit
set -o pipefail
set -o nounset
export CLUSTER_NAME=anthos-aws-v2
source $OUTPUT_FILE
gcloud alpha container aws clusters create $CLUSTER_NAME \
  --aws-region=$AWS_REGION --region=$GCP_REGION \
  --subnet-id=$CONTROL_PLANE_SUBNET_1,$CONTROL_PLANE_SUBNET_2,$CONTROL_PLANE_SUBNET_3 \
  --cluster-ipv4-cidr=10.1.0.0/16 \
  --service-ipv4-cidr=10.2.0.0/16 \
  --vpc-id=$VPC_ID \
  --services-lb-subnet-id=$PUBLIC_SERVICE_SUBNET \
  --cluster-version=1.19.9-gke.1900 \
  --database-encryption-key=$DB_KMS_KEY_ARN \
  --iam-instance-profile=$CONTROL_PLANE_PROFILE \
  --instance-type=t3.medium \
  --key-pair-name=$SSH_KEY_PAIR_NAME \
  --main-volume-size=10 \
  --root-volume-size=10 \
  --role-arn=$API_ROLE_ARN \
  --role-session-name=aws-v2-dev-session
