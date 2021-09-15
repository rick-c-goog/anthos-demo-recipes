#!/bin/bash

if test -f "$HOME/.startup-ran"; then
  /home/envoy/traffic-director/run.sh start
  echo "Skipping startup-script. Already run."
  exit 0
fi
export CARTHOST=$(curl -s http://metadata.google.internal/computeMetadata/v1/instance/attributes/cart-host -H "Metadata-Flavor: Google")
export PAYMENTHOST=$(curl -s http://metadata.google.internal/computeMetadata/v1/instance/attributes/payment-host -H "Metadata-Flavor: Google")
export DATACENTER=$(curl -s http://metadata.google.internal/computeMetadata/v1/instance/zone -H "Metadata-Flavor: Google" | cut -d '/' -f 4)
export HOSTNAME=$(curl -s http://metadata.google.internal/computeMetadata/v1/instance/name -H "Metadata-Flavor: Google")
export PROJECT=$(curl -s http://metadata.google.internal/computeMetadata/v1/project/project-id -H "Metadata-Flavor: Google")
export CARTHOST_IP=$(echo $CARTHOST | sed -e "s/http:\/\///g")
export PAYMENTHOST_IP=$(echo $PAYMENTHOST | sed -e "s/http:\/\///g")
export CART_FILE=$(curl -s http://metadata.google.internal/computeMetadata/v1/instance/attributes/cart-file -H "Metadata-Flavor: Google")
export CONTROL_PLANE=$(curl -s http://metadata.google.internal/computeMetadata/v1/instance/attributes/control-plane -H "Metadata-Flavor: Google")
export PROJECTNUM=$(curl -s http://metadata.google.internal/computeMetadata/v1/project/numeric-project-id -H "Metadata-Flavor: Google")
export NETWORK=$(curl -s http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/network -H "Metadata-Flavor: Google" | cut -d '/' -f 4)
export DEBIAN_FRONTEND=noninteractive

# Wait for package manager to finish
while (ps -A | grep apt) > /dev/null 2>&1; do
  echo 'Waiting for other package managers to finish'
  sleep 1
done

set -x
adduser --system --disabled-login envoy
wget -P /home/envoy https://storage.googleapis.com/traffic-director/traffic-director.tar.gz
tar -xzf /home/envoy/traffic-director.tar.gz -C /home/envoy
cat << END > /home/envoy/traffic-director/sidecar.env
ENVOY_USER=envoy
EXCLUDE_ENVOY_USER_FROM_INTERCEPT='true'
SERVICE_CIDR='$CARTHOST_IP,$PAYMENTHOST_IP'
GCP_PROJECT_NUMBER='$PROJECTNUM'
VPC_NETWORK_NAME='$NETWORK'
ENVOY_PORT='15001'
ENVOY_ADMIN_PORT='15000'
LOG_DIR='/var/log/envoy/'
LOG_LEVEL='info'
XDS_SERVER_CERT='/etc/ssl/certs/ca-certificates.crt'
TRACING_ENABLED='true'
ACCESSLOG_PATH='/var/log/envoy/access.log'
END
wget -O - https://storage.googleapis.com/traffic-director/demo/observability/envoy_stackdriver_trace_config.yaml >> /home/envoy/traffic-director/bootstrap_template.yaml

# Deploy docker
apt-get update -y
apt-get install apt-transport-https ca-certificates curl gnupg2 software-properties-common dirmngr -y
apt-key adv --fetch-keys https://download.docker.com/linux/debian/gpg
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable" -y
apt-get update -y
apt-get install docker-ce -y

# Deploy app
curl -sL https://deb.nodesource.com/setup_12.x | bash -
apt-get install -y nodejs

mkdir -p /app
cd /app
gsutil cp gs://${CART_FILE} - | tar zxf -

npm update
npm install

npm install -g pm2
npm install --save @google-cloud/trace-agent
NODE_ENV=production PORT=80 CART_HOST=$CARTHOST PAYMENT_HOST=$PAYMENTHOST DATACENTER=$DATACENTER HOSTNAME=$HOSTNAME CONTROL_PLANE=$CONTROL_PLANE pm2 start ./bin/www
pm2 startup
pm2 save

/home/envoy/traffic-director/pull_envoy.sh
/home/envoy/traffic-director/run.sh start

cat << END >> /root/.bashrc
export PM2_HOME=/etc/.pm2
pm2 resurrect
END

touch $HOME/.startup-ran
