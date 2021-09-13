#!/bin/bash

kubectl create ns ob-demo
kubectl label namespace ob-demo istio-injection- istio.io/rev=asm-1104-6 --overwrite

kpt pkg get \
https://github.com/GoogleCloudPlatform/microservices-demo.git/release \
online-boutique

kubectl apply -n ob-demo -f online-boutique
