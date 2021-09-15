#!/bin/bash

if test -f "$HOME/.startup-ran"; then
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
apt-get update -y
apt-get install apt-transport-https ca-certificates curl gnupg2 software-properties-common dirmngr -y
# Deploy app
curl -sL https://deb.nodesource.com/setup_12.x | bash -
apt-get install -y nodejs

mkdir -p /app
cd /app
gsutil cp gs://${CART_FILE} - | tar zxf - 
if [ $? -ne 0 ]; then
  echo "Failed to retrieve cart application from storage"
  exit 1
fi
npm update
npm install

npm install -g pm2
NODE_ENV=production PORT=80 CART_HOST=$CARTHOST PAYMENT_HOST=$PAYMENTHOST DATACENTER=$DATACENTER HOSTNAME=$HOSTNAME CONTROL_PLANE=$CONTROL_PLANE pm2 start ./bin/www
pm2 startup
pm2 save
cat << END >> /root/.bashrc
export PM2_HOME=/etc/.pm2
pm2 resurrect
END

touch $HOME/.startup-ran
