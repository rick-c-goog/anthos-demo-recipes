

gcloud alpha container aws node-pools delete aws-v2-nodepool  --cluster=$CLUSTER_NAME     --location=$GCP_LOCATION

gcloud alpha container aws clusters delete $CLUSTER_NAME --location=$GCP_REGION 
