#!/bin/bash -x

envsubst < payment-delivery-cluster-a.yaml | kubectl apply --cluster ${CONTEXT_CLUSTER_REGION_A} -f -

envsubst < payment-delivery-cluster-b.yaml | kubectl apply --cluster ${CONTEXT_CLUSTER_REGION_B} -f -

PAYMENTDELIVERYNEG1=$(kubectl get service paymentdeliveryhost -o=jsonpath='{..cloud\.google\.com/neg-status}' --cluster ${CONTEXT_CLUSTER_REGION_A} | jq -r '.network_endpoint_groups["80"]')

PAYMENTDELIVERYNEG2=$(kubectl get service paymentdeliveryhost -o=jsonpath='{..cloud\.google\.com/neg-status}' --cluster ${CONTEXT_CLUSTER_REGION_B} | jq -r '.network_endpoint_groups["80"]')

gcloud compute backend-services create payment-delivery-service \
    --global \
    --health-checks  payment-hc \
    --load-balancing-scheme INTERNAL_SELF_MANAGED

gcloud compute backend-services add-backend payment-delivery-service \
    --global \
    --network-endpoint-group $PAYMENTDELIVERYNEG1 \
    --network-endpoint-group-zone $DATACENTER1 \
    --balancing-mode RATE \
    --max-rate-per-endpoint 5


gcloud compute backend-services add-backend payment-delivery-service \
    --global \
    --network-endpoint-group $PAYMENTDELIVERYNEG2 \
    --network-endpoint-group-zone $DATACENTER2 \
    --balancing-mode RATE \
    --max-rate-per-endpoint 5


gcloud compute url-maps import payment-url-map \
    --source ./payment-url-map-canary.yaml \
    --global -q

