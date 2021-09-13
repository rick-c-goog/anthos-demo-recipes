#!/bin/bash

# This script creates a bastion for AWS which can be used as an HTTP proxy by
# kubectl.
#
# This requires:
#  - The "aws" command to be installed and configured.
#  - The "jq" command JSON line tool to be installed.
#
# Run without any arguments to see the correct usage.

set -o errexit
set -o pipefail
set -o nounset

scriptDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$scriptDir/base.sh"

function print_usage() {
  >&2 echo 'Usage: create-bastion.sh OUTPUT_PATH

Arguments:

OUTPUT_PATH:
  Path to file where the results will be written to. This output
  file will be a shell script which can be sourced to define
  the outputs as shell variables. This path must not already
  exist.

Required input environment variables:

AWS_REGION:
VPC_ID:
SSH_KEY_PAIR_NAME:
PUBLIC_SUBNET:

Optional input environment variables:

AWS_RESOURCE_NAME_PREFIX:
  Prefix to use when naming resources (IAM roles, instance
  profiles). If not specified, will default to $USER-dev.
'
}

# ------------------------------------------------------------------------------
# Create security group
# ------------------------------------------------------------------------------

function create_bastion_security_group() {
  BASTION_SG_NAME=$AWS_RESOURCE_NAME_PREFIX-bastion

  BASTION_SG_ID=$(aws ec2 create-security-group \
    --group-name "$AWS_RESOURCE_NAME_PREFIX-bastion" \
    --description "bastion rules" \
    --vpc-id $VPC_ID | jq -r '.GroupId')

  save_variable "BASTION_SG_NAME"
  save_variable "BASTION_SG_ID"

  aws ec2 authorize-security-group-ingress \
    --group-id $BASTION_SG_ID \
    --protocol tcp \
    --port 22 \
    --cidr 0.0.0.0/0

  aws ec2 revoke-security-group-egress \
    --group-id $BASTION_SG_ID \
    --protocol -1 \
    --cidr 0.0.0.0/0

  aws ec2 authorize-security-group-egress \
    --group-id $BASTION_SG_ID \
    --protocol tcp \
    --port 80 \
    --cidr 0.0.0.0/0

  aws ec2 authorize-security-group-egress \
    --group-id $BASTION_SG_ID \
    --protocol tcp \
    --port 443 \
    --cidr 0.0.0.0/0
}

# ------------------------------------------------------------------------------
# Create EC2 instance
# ------------------------------------------------------------------------------

function create_bastion_instance() {
  BASTION_AMI_ID=$(aws ec2 describe-images \
      --region $AWS_REGION \
      --owners "099720109477" \
      --filters "Name=name,Values=ubuntu-minimal/images/hvm-ssd/ubuntu-bionic-18.04-amd64-minimal-20201014" "Name=virtualization-type,Values=hvm" | jq -r '.Images[0].ImageId')

  BASTION_NAME=$AWS_RESOURCE_NAME_PREFIX-bastion

  BASTION_ID=$(aws ec2 run-instances --image-id $BASTION_AMI_ID \
   --count 1 --instance-type t3.medium --key-name $SSH_KEY_PAIR_NAME \
   --security-group-ids $BASTION_SG_ID --subnet-id $PUBLIC_SUBNET \
   --tag-specifications \
     "ResourceType=instance,Tags=[{Key=Name,Value=$BASTION_NAME}]" \
   --user-data '#!/bin/bash
set -eu -o pipefail

apt-get -qqy update
apt-get -qqy install privoxy --no-install-recommends
' | jq -r '.Instances[0].InstanceId')

  save_variable "BASTION_NAME"
  save_variable "BASTION_ID"
}

# ------------------------------------------------------------------------------
# Get bastion IP
# ------------------------------------------------------------------------------

function get_bastion_ip() {
  BASTION_IP=$(aws ec2 describe-instances \
		--instance-ids $BASTION_ID \
		--query Reservations[].Instances[].PublicIpAddress \
		--output=text)

  save_variable "BASTION_IP"
}

function main() {
  if [ $# -ne 1 ]; then
    print_usage
    exit 1
  fi

  require_variable "AWS_REGION"
  require_variable "VPC_ID"
  require_variable "SSH_KEY_PAIR_NAME"
  require_variable "PUBLIC_SUBNET"

  OUTPUT_PATH="$1"
  echo "Will save resources to $OUTPUT_PATH"

  init_output_file

  # Get optional input variables with defaults.
  if [[ ! -v AWS_RESOURCE_NAME_PREFIX ]]; then
    AWS_RESOURCE_NAME_PREFIX="$USER-dev"
  fi

  create_bastion_security_group
  create_bastion_instance
  get_bastion_ip

  echo "Completed successfully!"
  echo "Variables were written to $OUTPUT_PATH"
}

main "$@"
