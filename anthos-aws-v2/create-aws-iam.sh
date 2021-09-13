#!/bin/bash

# This script creates the IAM resource dependencies needed for creating an
# Anthos on-AWS cluster:
#
# (1) [optional] Create a KMS key
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
  the outputs as shell variables.

Optional input environment variables:

AWS_RESOURCE_NAME_PREFIX:
  Prefix to use when naming resources (IAM roles, instance
  profiles). If not specified, will default to $USER-dev.

DB_KMS_KEY_ARN:
  ARN to an exiting KMS key to use for encrypting etcd.
  If omitted, one will be created for you. The IAM roles
  reference this key ARN.

PROJECT_ID:
  GCP Project ID. If unspecified, will default to
  `gcloud config get-value project`.

P4SA_PROJECT:
  Only used internally. Defaults to
  "gcp-sa-gkemulticloud.iam.gserviceaccount.com".
'
}

# ------------------------------------------------------------------------------
# KMS Encryption Key
# ------------------------------------------------------------------------------

function create_kms_key() {
  DB_KMS_KEY_ARN="$(aws kms create-key --description "AWS KMS Key" | jq -r '.KeyMetadata.Arn')"
}

# ------------------------------------------------------------------------------
# IAM role: Anthos Multi-Cloud API
# ------------------------------------------------------------------------------

function create_api_role() {
  API_ROLE_ARN=$(aws iam create-role --role-name $AWS_RESOURCE_NAME_PREFIX-api-role \
  --assume-role-policy-document '{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Federated": "accounts.google.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "accounts.google.com:sub": "service-'$PROJECT_NUMBER'@'$P4SA_PROJECT'"
        }
      }
    }
  ]
}' | jq -r '.Role.Arn')

  save_variable "API_ROLE_ARN"

  API_POLICY_ARN=$(aws iam create-policy --policy-name $AWS_RESOURCE_NAME_PREFIX-api-policy \
      --policy-document '{
  "Version": "2012-10-17",
  "Statement": [
    {
        "Sid": "",
        "Effect": "Allow",
        "Action": [
            "kms:Encrypt",
            "kms:DescribeKey",
            "iam:PassRole",
            "elasticloadbalancing:DescribeTargetHealth",
            "elasticloadbalancing:DescribeTargetGroups",
            "elasticloadbalancing:DescribeLoadBalancers",
            "elasticloadbalancing:DescribeListeners",
            "elasticloadbalancing:DeleteTargetGroup",
            "elasticloadbalancing:DeleteLoadBalancer",
            "elasticloadbalancing:DeleteListener",
            "elasticloadbalancing:CreateTargetGroup",
            "elasticloadbalancing:CreateLoadBalancer",
            "elasticloadbalancing:CreateListener",
            "elasticloadbalancing:AddTags",
            "ec2:RunInstances",
            "ec2:RevokeSecurityGroupIngress",
            "ec2:RevokeSecurityGroupEgress",
            "ec2:DescribeVpcs",
            "ec2:DescribeVolumes",
            "ec2:DescribeSubnets",
            "ec2:DescribeSecurityGroups",
            "ec2:DescribeNetworkInterfaces",
            "ec2:DescribeLaunchTemplates",
            "ec2:DescribeKeyPairs",
            "ec2:DeleteVolume",
            "ec2:DeleteTags",
            "ec2:DeleteSecurityGroup",
            "ec2:DeleteNetworkInterface",
            "ec2:DeleteLaunchTemplate",
            "ec2:CreateVolume",
            "ec2:CreateTags",
            "ec2:CreateSecurityGroup",
            "ec2:CreateNetworkInterface",
            "ec2:CreateLaunchTemplate",
            "ec2:AuthorizeSecurityGroupIngress",
            "ec2:AuthorizeSecurityGroupEgress",
            "autoscaling:UpdateAutoScalingGroup",
            "autoscaling:TerminateInstanceInAutoScalingGroup",
            "autoscaling:DescribeAutoScalingGroups",
            "autoscaling:DeleteTags",
            "autoscaling:DeleteAutoScalingGroup",
            "autoscaling:CreateOrUpdateTags",
            "autoscaling:CreateAutoScalingGroup"
        ],
        "Resource": "*"
    }
  ]
}' | jq -r '.Policy.Arn')
  save_variable "API_POLICY_ARN"

  aws iam attach-role-policy \
    --role-name $AWS_RESOURCE_NAME_PREFIX-api-role \
    --policy-arn $API_POLICY_ARN
}

# ------------------------------------------------------------------------------
# IAM instance profile: Control plane
# ------------------------------------------------------------------------------

function create_iam_cp_profile() {
  aws iam create-role --role-name $AWS_RESOURCE_NAME_PREFIX-cp-role \
  --assume-role-policy-document '{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}'

  CP_POLICY_ARN=$(aws iam create-policy --policy-name $AWS_RESOURCE_NAME_PREFIX-cp-policy \
    --policy-document '{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "",
            "Effect": "Allow",
            "Action": [
                "iam:CreateServiceLinkedRole",
                "elasticloadbalancing:SetLoadBalancerPoliciesOfListener",
                "elasticloadbalancing:SetLoadBalancerPoliciesForBackendServer",
                "elasticloadbalancing:RegisterTargets",
                "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
                "elasticloadbalancing:ModifyTargetGroup",
                "elasticloadbalancing:ModifyLoadBalancerAttributes",
                "elasticloadbalancing:ModifyListener",
                "elasticloadbalancing:DetachLoadBalancerFromSubnets",
                "elasticloadbalancing:DescribeTargetHealth",
                "elasticloadbalancing:DescribeTargetGroups",
                "elasticloadbalancing:DescribeLoadBalancers",
                "elasticloadbalancing:DescribeLoadBalancerPolicies",
                "elasticloadbalancing:DescribeLoadBalancerAttributes",
                "elasticloadbalancing:DescribeListeners",
                "elasticloadbalancing:DeregisterTargets",
                "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
                "elasticloadbalancing:DeleteTargetGroup",
                "elasticloadbalancing:DeleteLoadBalancerListeners",
                "elasticloadbalancing:DeleteLoadBalancer",
                "elasticloadbalancing:DeleteListener",
                "elasticloadbalancing:CreateTargetGroup",
                "elasticloadbalancing:CreateLoadBalancerPolicy",
                "elasticloadbalancing:CreateLoadBalancerListeners",
                "elasticloadbalancing:CreateLoadBalancer",
                "elasticloadbalancing:CreateListener",
                "elasticloadbalancing:ConfigureHealthCheck",
                "elasticloadbalancing:AttachLoadBalancerToSubnets",
                "elasticloadbalancing:ApplySecurityGroupsToLoadBalancer",
                "elasticloadbalancing:AddTags",
                "ec2:RevokeSecurityGroupIngress",
                "ec2:ModifyVolume",
                "ec2:ModifyInstanceAttribute",
                "ec2:DetachVolume",
                "ec2:DescribeVpcs",
                "ec2:DescribeVolumesModifications",
                "ec2:DescribeVolumes",
                "ec2:DescribeTags",
                "ec2:DescribeSubnets",
                "ec2:DescribeSnapshots",
                "ec2:DescribeSecurityGroups",
                "ec2:DescribeRouteTables",
                "ec2:DescribeRegions",
                "ec2:DescribeLaunchTemplateVersions",
                "ec2:DescribeInstances",
                "ec2:DeleteVolume",
                "ec2:DeleteTags",
                "ec2:DeleteSnapshot",
                "ec2:DeleteSecurityGroup",
                "ec2:DeleteRoute",
                "ec2:CreateVolume",
                "ec2:CreateTags",
                "ec2:CreateSnapshot",
                "ec2:CreateSecurityGroup",
                "ec2:CreateRoute",
                "ec2:AuthorizeSecurityGroupIngress",
                "ec2:AttachVolume",
                "ec2:AttachNetworkInterface",
                "autoscaling:TerminateInstanceInAutoScalingGroup",
                "autoscaling:SetDesiredCapacity",
                "autoscaling:DescribeTags",
                "autoscaling:DescribeLaunchConfigurations",
                "autoscaling:DescribeAutoScalingInstances",
                "autoscaling:DescribeAutoScalingGroups"
            ],
            "Resource": "*"
        },
        {
            "Sid": "",
            "Effect": "Allow",
            "Action": [
                "kms:Encrypt",
                "kms:Decrypt"
            ],
            "Resource": "'$DB_KMS_KEY_ARN'"
        }
    ]
}' | jq -r '.Policy.Arn')

  save_variable "CP_POLICY_ARN"

  aws iam attach-role-policy --role-name $AWS_RESOURCE_NAME_PREFIX-cp-role --policy-arn \
    $CP_POLICY_ARN

  CONTROL_PLANE_PROFILE=$AWS_RESOURCE_NAME_PREFIX-cp-profile
  aws iam create-instance-profile \
    --instance-profile-name $CONTROL_PLANE_PROFILE
  save_variable "CONTROL_PLANE_PROFILE"

  aws iam add-role-to-instance-profile \
    --instance-profile-name $CONTROL_PLANE_PROFILE \
    --role-name $AWS_RESOURCE_NAME_PREFIX-cp-role
}

# ------------------------------------------------------------------------------
# IAM instance profile: Node pool
# ------------------------------------------------------------------------------

function create_iam_np_profile() {
  aws iam create-role --role-name $AWS_RESOURCE_NAME_PREFIX-np-role \
  --assume-role-policy-document '{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}'

 NP_POLICY_ARN=$(aws iam create-policy \
    --policy-name $AWS_RESOURCE_NAME_PREFIX-np-policy \
    --policy-document '{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "",
            "Effect": "Allow",
            "Action": [
               "autoscaling:DescribeAutoScalingGroups",
               "ec2:AttachNetworkInterface",
               "ec2:DescribeInstances",
               "ec2:DescribeTags"
            ],
            "Resource": "*"
        },
        {
            "Sid": "",
            "Effect": "Allow",
            "Action": [
                "kms:Encrypt",
                "kms:Decrypt"
            ],
            "Resource": "'$DB_KMS_KEY_ARN'"
        }
    ]
}' | jq -r '.Policy.Arn')

  save_variable "NP_POLICY_ARN"

  aws iam attach-role-policy --role-name $AWS_RESOURCE_NAME_PREFIX-np-role --policy-arn \
        $NP_POLICY_ARN

  NODEPOOL_PROFILE=$AWS_RESOURCE_NAME_PREFIX-np-profile
  aws iam create-instance-profile \
      --instance-profile-name $NODEPOOL_PROFILE 

  save_variable "NODEPOOL_PROFILE"

  aws iam add-role-to-instance-profile \
    --instance-profile-name $NODEPOOL_PROFILE \
    --role-name $AWS_RESOURCE_NAME_PREFIX-np-role
}

function main() {
  if [ $# -ne 1 ]; then
    print_usage
    exit 1
  fi

  OUTPUT_PATH="$1"
  echo "Will save resources to $OUTPUT_PATH"

  init_output_file

  # Get optional input variables with defaults.

  if [[ ! -v P4SA_PROJECT ]]; then
    P4SA_PROJECT="gcp-sa-gkemulticloud.iam.gserviceaccount.com"
  fi

  if [[ ! -v AWS_RESOURCE_NAME_PREFIX ]]; then
    AWS_RESOURCE_NAME_PREFIX="$USER-dev"
  fi

  if [[ ! -v PROJECT_ID ]]; then
    PROJECT_ID="$(gcloud config get-value project)"
  fi

  PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format "value(projectNumber)")

  save_variable "PROJECT_ID"
  save_variable "PROJECT_NUMBER"

  # Create a KMS key if one is not provided.
  if [[ ! -v DB_KMS_KEY_ARN ]]; then
    create_kms_key
  fi
  save_variable "DB_KMS_KEY_ARN"

  create_api_role
  create_iam_cp_profile
  create_iam_np_profile

  echo "Completed successfully!"
  echo "Variables were written to $OUTPUT_PATH"
}

main "$@"
