#!/bin/bash -x

envsubst < payment-cluster-a.yaml | kubectl apply --cluster ${CONTEXT_CLUSTER_REGION_A} -f -

envsubst < payment-cluster-b.yaml | kubectl apply --cluster ${CONTEXT_CLUSTER_REGION_B} -f -

gcloud compute health-checks create http payment-hc --port=5001 --check-interval=1 --healthy-threshold=2 --unhealthy-threshold=3 --timeout=1

gcloud compute backend-services create payment-service --global --health-checks payment-hc --load-balancing-scheme INTERNAL_SELF_MANAGED

gcloud compute backend-services add-backend payment-service --global \
    --network-endpoint-group $(kubectl get service paymenthost -o=jsonpath='{..cloud\.google\.com/neg-status}' --cluster ${CONTEXT_CLUSTER_REGION_A} | jq -r '.network_endpoint_groups["80"]') \
    --network-endpoint-group-zone $DATACENTER1 \
    --balancing-mode RATE --max-rate-per-endpoint 5

gcloud compute backend-services add-backend payment-service --global \
    --network-endpoint-group $(kubectl get service paymenthost -o=jsonpath='{..cloud\.google\.com/neg-status}' --cluster ${CONTEXT_CLUSTER_REGION_B} | jq -r '.network_endpoint_groups["80"]') \
    --network-endpoint-group-zone $DATACENTER2 \
    --balancing-mode RATE --max-rate-per-endpoint 5

gcloud compute url-maps create payment-url-map --default-service payment-service
gcloud compute target-http-proxies create payment-proxy --url-map payment-url-map

gcloud compute forwarding-rules create payment-forwarding-rule \
    --global --target-http-proxy payment-proxy --ports 80 --address 10.128.0.6 \
    --network $VPCNET --load-balancing-scheme INTERNAL_SELF_MANAGED


