#!/bin/bash -x
echo "Command usage: source ./create_envs.sh"
export CLUSTER1_NAME=$(terraform output -raw cluster1-name)
export CLUSTER2_NAME=$(terraform output -raw cluster2-name)
export CLUSTER_REGION_A=$(terraform output -raw region-1)
export CLUSTER_REGION_B=$(terraform output -raw region-2)
export DATACENTER1=$(terraform output -raw datacenter-1)
export DATACENTER2=$(terraform output -raw datacenter-2)
export TD_PROJECT_ID=$(terraform output -raw project-id)
export CONTROL_PLANE=$(terraform output -raw control-plane)
export GCR_LOCATION=$(terraform output -raw gcr-location)
export PAYMENT_SVC_IMG="payment-service:latest"
export PAYMENT_SVC_DELIVERY_IMG="payment-service-delivery:latest"
export VPCNET=$(terraform output -raw vpcnet)
export SUBNET_A=$(terraform output -raw subnet-a)
export SUBNET_B=$(terraform output -raw subnet-b)
export CARTFILE=$(terraform output -raw cart-file)
gcloud config set project $TD_PROJECT_ID
gcloud container clusters get-credentials ${CLUSTER1_NAME} --zone ${DATACENTER1}
export CONTEXT_CLUSTER_REGION_A=$(kubectl config current-context)
gcloud container clusters get-credentials ${CLUSTER2_NAME} --zone ${DATACENTER2}
export CONTEXT_CLUSTER_REGION_B=$(kubectl config current-context)


