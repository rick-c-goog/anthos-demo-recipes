NODEPOOL_NAME=aws-v2-nodepool 
source ./aws-resources.sh
gcloud alpha container aws node-pools create $NODEPOOL_NAME \
  --cluster=$CLUSTER_NAME --instance-type=t3.medium \
  --ssh-ec2-key-pair=$SSH_KEY_PAIR_NAME  --root-volume-size=10 \
  --iam-instance-profile=$NODEPOOL_PROFILE --node-version=1.19.10-gke.1000 \
  --min-nodes=1 --max-nodes=5 \
  --location=$GCP_REGION \
  --subnet-id=$NODEPOOL_SUBNET \
  --max-pods-per-node=110
