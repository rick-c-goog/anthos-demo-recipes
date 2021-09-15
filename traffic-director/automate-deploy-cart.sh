#!/bin/bash -x

gcloud beta compute instance-templates create tpl-cart-a \
  --service-proxy enabled,tracing=ON,access-log=/var/log/envoy/access.log \
  --machine-type=e2-standard-2 \
  --image-family=debian-9 --image-project=debian-cloud \
  --scopes=https://www.googleapis.com/auth/cloud-platform \
  --subnet=${SUBNET_A} \
  --region=${CLUSTER_REGION_A} -q --no-address \
  --metadata-from-file startup-script=vm-scripts/cart-startup.sh,shutdown-script=vm-scripts/cart-shutdown.sh \
  --metadata version=latest,cart-host=http://10.128.0.4,\
payment-host=http://10.128.0.6,cart-file=${CARTFILE},\
control-plane=control-plane
gcloud beta compute instance-templates create tpl-cart-b \
  --service-proxy enabled,tracing=ON,access-log=/var/log/envoy/access.log \
  --machine-type=e2-standard-2 \
  --image-family=debian-9 --image-project=debian-cloud \
  --scopes=https://www.googleapis.com/auth/cloud-platform \
  --subnet=${SUBNET_B} \
  --region=${CLUSTER_REGION_B} -q --no-address \
  --metadata-from-file startup-script=vm-scripts/cart-startup.sh,shutdown-script=vm-scripts/cart-shutdown.sh \
  --metadata version=latest,cart-host=http://10.128.0.4,\
payment-host=http://10.128.0.6,cart-file=${CARTFILE},\
control-plane=control-plane
gcloud compute instance-groups managed create \
  vm-cart-tddemo-${DATACENTER1} \
  --zone ${DATACENTER1} \
  --size=1 \
  --template=tpl-cart-a
gcloud compute instance-groups managed create \
  vm-cart-tddemo-${DATACENTER2} \
  --zone ${DATACENTER2} \
  --size=1 \
  --template=tpl-cart-b
gcloud compute health-checks create http app-cart-health-check
gcloud compute backend-services create app-cart-bs \
 --global \
 --load-balancing-scheme=INTERNAL_SELF_MANAGED \
 --connection-draining-timeout=30s \
 --health-checks app-cart-health-check
gcloud compute backend-services add-backend app-cart-bs \
  --instance-group vm-cart-tddemo-${DATACENTER1} \
  --instance-group-zone ${DATACENTER1} \
  --global
gcloud compute backend-services add-backend app-cart-bs \
  --instance-group vm-cart-tddemo-${DATACENTER2} \
  --instance-group-zone ${DATACENTER2} \
  --global
gcloud compute url-maps create cart-service \
   --default-service app-cart-bs
gcloud compute target-http-proxies create app-cart-proxy \
   --url-map=cart-service
gcloud compute forwarding-rules create app-cart-fr \
   --global \
   --load-balancing-scheme=INTERNAL_SELF_MANAGED \
   --address=10.128.0.4 \
   --target-http-proxy=app-cart-proxy \
   --ports=80 \
   --network=${VPCNET}
