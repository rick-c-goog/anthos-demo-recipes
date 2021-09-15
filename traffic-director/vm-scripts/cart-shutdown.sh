#!/bin/bash
export HOSTNAME=$(curl -s http://metadata.google.internal/computeMetadata/v1/instance/name -H "Metadata-Flavor: Google")
export PROJECT=$(curl -s http://metadata.google.internal/computeMetadata/v1/project/project-id -H "Metadata-Flavor: Google")

#Pubsub Subscription cleanup
gcloud pubsub subscriptions delete $HOSTNAME --project=$PROJECT --quiet