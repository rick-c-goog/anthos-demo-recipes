# anthos attached EKS cluster
Steps:

MFA token pre-requisites:
check $HOME/aws-sts.sh and append the following variable defined:
export AWS_ACCESS_KEY_ID=$ACCESS
export AWS_SECRET_ACCESS_KEY=$SECRET
export AWS_SESSION_TOKEN=$SESSION

1. check create_eks.sh parameters and variables

2. ./create_eks.sh, will prompt for MFA token if mfa required

3. If there is error after the cluster creation,
Unable to connect to the server: dial tcp 44.199.7.55:443: connect: connection timed out
simply re-run the script
./create_eks.sh
4. check the cluster is registered and it registered and logedin in console.
5. For kubectl command, try the following:
gcloud container hub memberships list
gcloud container hub memberships get-credentials ClusterName  #replace cluster name
kubectl get nodes