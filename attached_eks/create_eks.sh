export PROJECT_ID=$(gcloud config get-value project)
export AWS_REGION=us-east-1
envsubst < "./terraform.tfvars.jsontemplate" >  "terraform.tfvars.json"
set -e 
echo "enter AWS mfa token:"
read -n 6 -p "mfa token:" MFATOKEN
source $HOME/aws-sts.sh $MFATOKEN
terraform init
terraform  apply --auto-approve
