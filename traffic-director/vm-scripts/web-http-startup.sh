#!/bin/bash -x

version=latest
carthost=$(curl -s http://metadata.google.internal/computeMetadata/v1/instance/attributes/cart-host -H "Metadata-Flavor: Google")
paymenthost=$(curl -s http://metadata.google.internal/computeMetadata/v1/instance/attributes/payment-host -H "Metadata-Flavor: Google")
project=$(curl -s http://metadata.google.internal/computeMetadata/v1/project/project-id -H "Metadata-Flavor: Google")
datacenter=$(curl -s http://metadata.google.internal/computeMetadata/v1/instance/zone -H "Metadata-Flavor: Google" | cut -d '/' -f 4)
hostname=$(curl -s http://metadata.google.internal/computeMetadata/v1/instance/name -H "Metadata-Flavor: Google")
projectnum=$(curl -s http://metadata.google.internal/computeMetadata/v1/project/numeric-project-id -H "Metadata-Flavor: Google")
network=$(curl -s http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/network -H "Metadata-Flavor: Google" | cut -d '/' -f 4)
export CONTROL_PLANE=$(curl -s http://metadata.google.internal/computeMetadata/v1/instance/attributes/control-plane -H "Metadata-Flavor: Google")
export DOCKER_IMAGE=$(curl -s http://metadata.google.internal/computeMetadata/v1/instance/attributes/web-docker-img -H "Metadata-Flavor: Google"):$version
export carthost_ip=$(echo $carthost | sed -e "s/http:\/\///g")
export paymenthost_ip=$(echo $paymenthost | sed -e "s/http:\/\///g")
if test -f "/.startup-ran"; then
  /home/envoy/traffic-director-xdsv3/run.sh start
  docker pull $DOCKER_IMAGE
  docker run -d --rm -e DATACENTER=$datacenter -e PORT=80 -e CART_HOST=$carthost -e PAYMENT_HOST=$paymenthost \
  -e HOSTNAME=$hostname -e CONTROL_PLANE=$CONTROL_PLANE --network host $DOCKER_IMAGE
  echo "Skipping startup-script. Already run."
  exit 0
fi
# Makes debconf use a frontend that expects no interactive input
export DEBIAN_FRONTEND=noninteractive

# Wait for package manager to finish
while (ps -A | grep apt) > /dev/null 2>&1; do
  echo 'Waiting for other package managers to finish'
  sleep 1
done

adduser --system --disabled-login envoy
wget -P /home/envoy https://storage.googleapis.com/traffic-director/traffic-director-xdsv3.tar.gz
tar -xzf /home/envoy/traffic-director-xdsv3.tar.gz -C /home/envoy
cat << END > /home/envoy/traffic-director-xdsv3/sidecar.env
ENVOY_IMAGE='envoyproxy/envoy:v1.16.3'
ENVOY_USER=envoy
EXCLUDE_ENVOY_USER_FROM_INTERCEPT='true'
SERVICE_CIDR='$carthost_ip,$paymenthost_ip'
GCP_PROJECT_NUMBER='$projectnum'
VPC_NETWORK_NAME='$network'
ENVOY_PORT='15001'
ENVOY_ADMIN_PORT='15000'
LOG_DIR='/var/log/envoy/'
LOG_LEVEL='info'
XDS_SERVER_CERT='/etc/ssl/certs/ca-certificates.crt'
TRACING_ENABLED='true'
ACCESSLOG_PATH='/var/log/envoy/access.log'
BACKEND_INBOUND_PORTS=''
INTERCEPT_INBOUND_PORTS=''
END
wget -O - https://storage.googleapis.com/traffic-director/demo/observability/envoy_stackdriver_trace_config.yaml >> /home/envoy/traffic-director-xdsv3/bootstrap_template.yaml

apt-get update -y
apt-get install apt-transport-https ca-certificates curl gnupg2 software-properties-common dirmngr -y
apt-key adv --fetch-keys https://download.docker.com/linux/debian/gpg
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable" -y
apt-get update -y
apt-get install docker-ce -y

gcloud auth configure-docker --quiet
docker pull $DOCKER_IMAGE
docker run -d --rm -e DATACENTER=$datacenter -e PORT=80 -e CART_HOST=$carthost -e PAYMENT_HOST=$paymenthost \
-e HOSTNAME=$hostname -e CONTROL_PLANE=$CONTROL_PLANE --network host $DOCKER_IMAGE
cd /home/envoy/traffic-director-xdsv3
./run.sh start

#Pubsub Topic Creation
# gcloud pubsub subscriptions create $hostname --topic=$CONTROL_PLANE --topic-project=$project --quiet

touch $HOME/.startup-ran