NODEPOOL_NAME=aws-v2-nodepool 
source $OUTPUT_FILE
gcloud alpha container aws node-pools create $NODEPOOL_NAME \
  --cluster=$CLUSTER_NAME --instance-type=t3.medium \
  --key-pair-name=$SSH_KEY_PAIR_NAME --root-volume-size=10 \
  --iam-instance-profile=$NODEPOOL_PROFILE --node-version=1.19.10-gke.1000 \
  --enable-autoscaling --min-nodes=1 --max-nodes=5 \
  --region=$GCP_REGION \
  --subnet-id=$NODEPOOL_SUBNET \
  --max-pods-per-node=110
