provider "aws" {
  version = "3.54.0"
  region  = var.region

  # Prevent terraform from removing the tags AMC adds to shared
  # resources like subnets.
  ignore_tags {
    key_prefixes = ["kubernetes.io/cluster/"]
  }
}
