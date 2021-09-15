#!/bin/bash
# Author: mhanline@google.com
# Purpose: Removes user-configured setup from the Traffic Director Codelab. (2020 version)
yellow='\033[1;33m'
nc='\033[0m' # No Color
if [ -z "${VPCNET}" ]; then
  echo "You haven't set your environment variables, i.e. source create_envs.sh"
  exit 1
fi
if [ "$1" == "-fw" ]; then
  echo -e "Deleting ${yellow}GCE Enforcer Firewll Rules${nc}."
  gcloud compute firewall-rules list --filter="network=${VPCNET}" --format="value(name)" | awk '{system("gcloud compute firewall-rules delete -q "$1)}'
  exit 0
fi
echo -e "Deleting ${yellow}Forwarding Rules${nc}."
gcloud compute forwarding-rules list --format="value(name)" | egrep "payment|app-cart" | awk '{system("gcloud compute forwarding-rules delete -q --global "$1)}'
echo -e "Deleting ${yellow}Target HTTP Proxies${nc}."
gcloud compute target-http-proxies list --format="value(name)" | egrep "payment|app-cart" | awk '{system("gcloud compute target-http-proxies delete -q --global "$1)}'
echo -e "Deleting ${yellow}URL Maps${nc}"
gcloud compute url-maps list --format="value(name)" | egrep "payment|cart-service" | awk '{system("gcloud compute url-maps delete -q --global "$1)}'
echo -e "Deleting ${yellow}Backend Services${nc}"
gcloud compute backend-services list --format="value(name)" | egrep "payment|app-cart" | awk '{system("gcloud compute backend-services delete --global -q "$1)}'
echo -e "Deleting ${yellow}Health Checks${nc}"
gcloud compute health-checks list --format="value(name)" | egrep "payment|app-cart" | awk '{system("gcloud compute health-checks delete --global -q "$1)}'
echo -e "Deleting ${yellow}NEGs${nc}"
gcloud compute network-endpoint-groups list --format="value(name,zone)" | awk '{system("gcloud compute network-endpoint-groups delete -q "$1 " --zone="$2)}'
echo -e "Deleting ${yellow}Managed Instance Groups${nc}"
gcloud compute instance-groups managed list --format="value(name,zone)" | egrep "vm-cart-tddemo" | awk '{system("gcloud compute instance-groups managed delete -q "$1 " --zone="$2)}'
echo -e "Deleting ${yellow}Instance Templates${nc}"
gcloud compute instance-templates list --format="value(name)" | egrep "cart" | awk '{system("gcloud compute instance-templates delete -q "$1)}'
