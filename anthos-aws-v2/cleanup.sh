#!/bin/bash
source  ./aws-resources.sh
gcloud alpha container aws node-pools delete aws-v2-nodepool  --cluster=$CLUSTER_NAME     --location=$GCP_REGION

gcloud alpha container aws clusters delete $CLUSTER_NAME --location=$GCP_REGION 

 aws iam delete-instance-profile --instance-profile-name $CONTORL_PLANE_PROFILE  --region  $AWS_REGION
 aws iam delete-instance-profile --instance-profile-name $NODEPOOL_PROFILE  --region  $AWS_REGION
