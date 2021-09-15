#!/bin/bash -x
project=$(curl -s http://metadata.google.internal/computeMetadata/v1/project/project-id -H "Metadata-Flavor: Google")
hostname=$(curl -s http://metadata.google.internal/computeMetadata/v1/instance/name -H "Metadata-Flavor: Google")

#Pubsub Topic Cleanup
#gcloud pubsub subscriptions delete $hostname --project=$project --quiet