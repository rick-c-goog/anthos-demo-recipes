export OUTPUT_FILE=aws-resources.sh

# Initialize $OUTPUT_FILE with the desired region.
echo "
export GCP_REGION='us-west1'
export AWS_REGION='us-west-2'

export AWS_ZONE_1='us-west-2a'
export AWS_ZONE_2='us-west-2b'
export AWS_ZONE_3='us-west-2c'
" > $OUTPUT_FILE

# Create a KMS key and the roles/policies/instance profiles.
source $OUTPUT_FILE
./create-aws-iam.sh $OUTPUT_FILE

# Create a VPC with subnets, internet gateway, NAT gateway, and configured route tables.
source $OUTPUT_FILE
./create-aws-vpc.sh $OUTPUT_FILE

# Create a private key to use for SSH
source $OUTPUT_FILE
export SSH_PRIVATE_KEY=ssh-private-key
./create-ssh-keypair.sh $OUTPUT_FILE

# Create an SSH bastion.
source $OUTPUT_FILE
./create-bastion.sh $OUTPUT_FILE
