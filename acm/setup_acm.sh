keyfile=acm-key

ssh-keygen -t rsa -b 4096 \
-C "rick-c-goog" \
-N '' \
-f $keyfile

gcloud container hub memberships get-credentials $CLUSTER_NAME
kubectl create ns config-management-system && \
kubectl create secret generic git-creds \
 --namespace=config-management-system \
 --from-file=ssh=$keyfile

PROJECT_ID=$(gcloud config get-value project)
gcloud beta container hub config-management apply \
      --membership=anthos-aws-v2 \
      --config=apply-spec.yaml \
      --project=$PROJECT_ID


gcloud beta container hub config-management apply \
     --membership=$CLUSTER_NAME \
     --config=spec-policycontroller.yaml \
     --project=$PROJECT_ID
