#!/bin/bash

# This script creates a sample AWS VPC that can be used with Anthos on AWS
# clusters. It requires:
#
# (1) A KMS key
# (2) Create an role Anthos Multi-Cloud API to assume.
# (3) Create an IAM instance profile for the control plane.
# (4) Create an IAM instance profile for the node pool.
#
# This requires:
#  - The "aws" command to be installed and configured.
#  - The "gcloud" command to be installed and configured.
#  - The "jq" command JSON line tool to be installed.
#
# Run without any arguments to see the correct usage.

set -o errexit
set -o pipefail
set -o nounset

scriptDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$scriptDir/base.sh"

function print_usage() {
  >&2 echo 'Usage: create-aws-iam.sh OUTPUT_PATH

Arguments:

OUTPUT_PATH:
  Path to file where the results will be written to. This output
  file will be a shell script which can be sourced to define
  the outputs as shell variables. This path must not already
  exist.

Required input environment variables:

AWS_ZONE_1: Example us-east-1a
AWS_ZONE_2:
AWS_ZONE_3:
'
}

# ------------------------------------------------------------------------------
# VPC
# ------------------------------------------------------------------------------

function create_vpc() {
  VPC_ID=$(aws ec2 create-vpc --cidr-block 10.0.0.0/16 | jq -r '.Vpc.VpcId' )
  save_variable "VPC_ID"
  aws ec2 modify-vpc-attribute --enable-dns-hostnames --vpc-id $VPC_ID
  aws ec2 modify-vpc-attribute --enable-dns-support --vpc-id $VPC_ID
}

# ------------------------------------------------------------------------------
# Control plane subnets
# ------------------------------------------------------------------------------

function create_control_plane_subnets() {
	CONTROL_PLANE_SUBNET_1=$(aws ec2 create-subnet \
    --availability-zone $AWS_ZONE_1 --vpc-id $VPC_ID --cidr-block "10.0.1.0/24" | jq -r '.Subnet.SubnetId')
  save_variable "CONTROL_PLANE_SUBNET_1"

	CONTROL_PLANE_SUBNET_2=$(aws ec2 create-subnet \
    --availability-zone $AWS_ZONE_2 --vpc-id $VPC_ID --cidr-block "10.0.2.0/24" | jq -r '.Subnet.SubnetId')
  save_variable "CONTROL_PLANE_SUBNET_2"

	CONTROL_PLANE_SUBNET_3=$(aws ec2 create-subnet \
    --availability-zone $AWS_ZONE_3 --vpc-id $VPC_ID --cidr-block "10.0.3.0/24" | jq -r '.Subnet.SubnetId')
  save_variable "CONTROL_PLANE_SUBNET_3"
}

# ------------------------------------------------------------------------------
# Public subnet
# ------------------------------------------------------------------------------

function create_public_subnet() {
	PUBLIC_SUBNET=$(aws ec2 create-subnet \
    --availability-zone $AWS_ZONE_1 --vpc-id $VPC_ID --cidr-block "10.0.101.0/24" | jq -r '.Subnet.SubnetId')
  save_variable "PUBLIC_SUBNET"

  aws ec2 modify-subnet-attribute \
    --map-public-ip-on-launch \
    --subnet-id $PUBLIC_SUBNET
}

# ------------------------------------------------------------------------------
# Internet Gateway
# ------------------------------------------------------------------------------

function create_internet_gateway() {
  INTERNET_GW_ID=$(aws ec2 create-internet-gateway | jq -r '.InternetGateway.InternetGatewayId')
  save_variable "INTERNET_GW_ID"

  aws ec2 attach-internet-gateway --internet-gateway-id $INTERNET_GW_ID \
    --vpc-id $VPC_ID
}

# ------------------------------------------------------------------------------
# Public subnet route table
# ------------------------------------------------------------------------------

function create_public_subnet_route_table() {
  PUBLIC_ROUTE_TABLE=$(aws ec2 create-route-table --vpc-id $VPC_ID | jq -r '.RouteTable.RouteTableId')
  save_variable "PUBLIC_ROUTE_TABLE"

  aws ec2 associate-route-table --route-table-id $PUBLIC_ROUTE_TABLE \
    --subnet-id $PUBLIC_SUBNET

  aws ec2 create-route --route-table-id $PUBLIC_ROUTE_TABLE \
    --destination-cidr-block 0.0.0.0/0 --gateway-id $INTERNET_GW_ID
}

# ------------------------------------------------------------------------------
# NAT Gateway
# ------------------------------------------------------------------------------

function create_nat_gateway() {
  NAT_EIP=$(aws ec2 allocate-address | jq -r '.AllocationId')
  NAT_GW=$(aws ec2 create-nat-gateway --allocation-id $NAT_EIP --subnet-id $PUBLIC_SUBNET | jq -r '.NatGateway.NatGatewayId')
  save_variable "NAT_GW"
  # Hack: Add some delay since creating NAT Gateway can be slow, and subsequent
  # commands might fail to find its ID.
  sleep 5
}

# ------------------------------------------------------------------------------
# Private subnets route table
# ------------------------------------------------------------------------------

function create_private_subnets_routetable() {
  aws ec2 create-route-table --vpc-id $VPC_ID
  PRIVATE_ROUTE_TABLE=$(aws ec2 create-route-table --vpc-id $VPC_ID | jq -r '.RouteTable.RouteTableId')

  aws ec2 create-route --route-table-id $PRIVATE_ROUTE_TABLE \
    --destination-cidr-block 0.0.0.0/0 --gateway-id $NAT_GW

  aws ec2 associate-route-table --route-table-id $PRIVATE_ROUTE_TABLE \
      --subnet-id $CONTROL_PLANE_SUBNET_1
  aws ec2 associate-route-table --route-table-id $PRIVATE_ROUTE_TABLE \
      --subnet-id $CONTROL_PLANE_SUBNET_2
  aws ec2 associate-route-table --route-table-id $PRIVATE_ROUTE_TABLE \
      --subnet-id $CONTROL_PLANE_SUBNET_3
}

# ------------------------------------------------------------------------------
# Service load balancer subnets
# ------------------------------------------------------------------------------

function create_service_load_balancer_subnets() {
  PUBLIC_SERVICE_SUBNET=$(aws ec2 create-subnet \
    --availability-zone $AWS_ZONE_1 \
    --vpc-id $VPC_ID \
    --cidr-block "10.0.102.0/24" | jq -r '.Subnet.SubnetId')
  save_variable "PUBLIC_SERVICE_SUBNET"

  aws ec2 modify-subnet-attribute \
    --map-public-ip-on-launch \
    --subnet-id $PUBLIC_SERVICE_SUBNET

  aws ec2 associate-route-table --route-table-id $PUBLIC_ROUTE_TABLE \
    --subnet-id $PUBLIC_SERVICE_SUBNET
}

# ------------------------------------------------------------------------------
# Nodepool subnet
# ------------------------------------------------------------------------------

function create_nodepool_subnet() {
  NODEPOOL_SUBNET=$(aws ec2 create-subnet \
    --availability-zone $AWS_ZONE_3 \
    --vpc-id $VPC_ID \
    --cidr-block "10.0.4.0/24" | jq -r '.Subnet.SubnetId' )

  aws ec2 associate-route-table \
    --route-table-id $PRIVATE_ROUTE_TABLE \
    --subnet-id $NODEPOOL_SUBNET
}

function main() {
  if [ $# -ne 1 ]; then
    print_usage
    exit 1
  fi

  require_variable "AWS_ZONE_1"
  require_variable "AWS_ZONE_2"
  require_variable "AWS_ZONE_3"

  OUTPUT_PATH="$1"
  echo "Will save resources to $OUTPUT_PATH"

  init_output_file

  save_variable "AWS_ZONE_1"
  save_variable "AWS_ZONE_2"
  save_variable "AWS_ZONE_3"

  create_vpc
  create_control_plane_subnets
  create_public_subnet
  create_internet_gateway
  create_public_subnet_route_table
  create_nat_gateway
  create_private_subnets_routetable
  create_service_load_balancer_subnets
  create_nodepool_subnet

  echo "Completed successfully!"
  echo "Variables were written to $OUTPUT_PATH"
}

main "$@"
