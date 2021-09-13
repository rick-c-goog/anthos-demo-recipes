keyfile=/pathToKeyFileName
kubectl create ns config-management-system && \
kubectl create secret generic git-creds \
 --namespace=config-management-system \
 --from-file=ssh=$keyfile

PROJECT_ID=$(gcloud config get value get-project))
gcloud beta container hub config-management apply \
      --membership=anthos-aws-v2 \
      --config=$HOME/anthos-aws-v2/acm/apply-spec.yaml \
      --project=$PROJECT_ID


gcloud beta container hub config-management apply \
     --membership=$CLUSTER_NAME \
     --config=spec-policycontroller.yaml \
     --project=$PROJECT_ID
