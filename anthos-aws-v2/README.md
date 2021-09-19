Simple shell scripts to create sample AWS resources for testing Anthos on-AWS.
This is a wrapper around the same aws CLI commands given in the document.

Here is an example of how to create resources in us-west-2:
Part 1:

# All the IDs/ARNs/Names created by the scripts will be
# saved to this file, formatted as shell script variables.
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

Part 2:
with everything runs properly, run
cat aws-resources.sh 

run the following to finalize cluster/nodepool creation:
./create_cluster.sh
./create_nodepool.sh

Part 3:
Open a separate terminal window to with ssh tunnel to bastion;
source ./aws-resources.sh
ssh -o 'ServerAliveInterval=30' \
      -o 'ServerAliveCountMax=3' \
      -o 'UserKnownHostsFile=/dev/null' \
      -o 'StrictHostKeyChecking=no' \
      -i $SSH_PRIVATE_KEY \
      -L 8118:127.0.0.1:8118 \
      ubuntu@$BASTION_IP -N

Part 4:
./register-hub.sh
./setup-connect-gateway.sh



