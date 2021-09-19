set -e 
export PROJECT_ID=$(gcloud config get-value project)
export AWS_REGION=us-east-1
export CLUSTER_NAME=attached-eks-test

###need to make sure envsubset
envsubst < "./terraform.tfvars.jsontemplate" >  "terraform.tfvars.json"
###comment out if you have aws following access keys, AWS_ACCESS_KEY_ID, AWS_ACCESS_KEY_CREDENTIAL, AWS_SESSION_TOKEN setup
echo "enter AWS mfa token:"
read -n 6 -p "mfa token:" MFATOKEN 
source $HOME/aws-sts.sh $MFATOKEN
###

terraform init
terraform  apply --auto-approve
