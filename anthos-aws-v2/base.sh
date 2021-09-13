#!/bin/bash

function init_output_file() {
  echo "" >> "$OUTPUT_PATH"
  echo "# Started: $(date)" >> "$OUTPUT_PATH"
}

function require_variable() {
  if [[ ! -v $1 ]]; then
    >&2 echo "ERROR: Variable $1 must be set" 
    print_usage
    exit 1
  fi
}

# Save an environment variable to the output file.
# This will also trace the value to stdout.
function save_variable() {
  local var_name
  var_name="$1"

  local var_value
  var_value="${!var_name}"

  local line
  line="export $var_name='$var_value'"
  echo ""
  echo "  >  $line"
  echo $line >> "$OUTPUT_PATH" 
}

# Trace aws command to stderr.
function aws() {
  >&2 echo ""
  >&2 echo "===Executing==========================="
  >&2 echo "aws $@"
  # Pause a bit before executing. Reduce chance that
  # sequences of commands fail due to resources not
  # being found.
  sleep 2
  >&2 echo "===Output=============================="
  local aws_output
  aws_output=$(command aws "$@")
  awsStatus="$?"
  >&2 echo "$aws_output"
  >&2 echo "======================================="
  if [ $awsStatus -ne 0 ]; then
    >&2 echo "AWS command failed with status: $awsStatus"
    exit 1
  fi
  echo "$aws_output"
}
