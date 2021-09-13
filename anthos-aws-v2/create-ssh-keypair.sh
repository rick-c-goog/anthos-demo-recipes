#!/bin/bash

# This script creates an SSH key pair - uploading the public key
# to AWS, and keeping the private key locally.
#
# Run without any arguments to see the correct usage.

set -o errexit
set -o pipefail
set -o nounset

scriptDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$scriptDir/base.sh"

function print_usage() {
  >&2 echo 'Usage: create-ssh-keypair.sh OUTPUT_PATH

Arguments:

OUTPUT_PATH:
  Path to file where the results will be written to. This output
  file will be a shell script which can be sourced to define
  the outputs as shell variables. This path must not already
  exist.

Required environment variables:

SSH_PRIVATE_KEY: Destination file path to write private key.

Optional input environment variables:

AWS_RESOURCE_NAME_PREFIX:
  Prefix to use when naming resources (IAM roles, instance
  profiles). If not specified, will default to $USER-dev.
'
}

function main() {
  if [ $# -ne 1 ]; then
    print_usage
    exit 1
  fi

  require_variable "SSH_PRIVATE_KEY"

  OUTPUT_PATH="$1"
  echo "Will save resources to $OUTPUT_PATH"

  init_output_file

  # Get optional input variables with defaults.
  if [[ ! -v AWS_RESOURCE_NAME_PREFIX ]]; then
    AWS_RESOURCE_NAME_PREFIX="$USER-dev"
  fi

  SSH_PRIVATE_KEY="$(realpath "$SSH_PRIVATE_KEY")"

  if [[ -f "$SSH_PRIVATE_KEY" ]]; then
    >&2 echo "ERROR: Private key already exists: $SSH_PRIVATE_KEY"
    exit 1
  fi

  ssh-keygen -t rsa -m PEM -b 4096 -C "$USER" \
    -f "$SSH_PRIVATE_KEY" -N "" 1>/dev/null

  save_variable "SSH_PRIVATE_KEY"

  SSH_KEY_PAIR_NAME="$AWS_RESOURCE_NAME_PREFIX-ssh-key"

  aws ec2 import-key-pair --key-name $SSH_KEY_PAIR_NAME \
    --public-key-material fileb://${SSH_PRIVATE_KEY}.pub

  save_variable "SSH_KEY_PAIR_NAME"

  echo "Completed successfully!"
  echo "Variables were written to $OUTPUT_PATH"
}

main "$@"
