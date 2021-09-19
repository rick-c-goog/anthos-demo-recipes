provider "aws" {
  version = "=2.70.0"
  region  = var.region

  # Prevent terraform from removing the tags AMC adds to shared
  # resources like subnets.
  ignore_tags {
    key_prefixes = ["kubernetes.io/cluster/"]
  }
}