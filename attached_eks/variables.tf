variable "name" { default = "aws-vpc-prod" }
variable "cidr" { default = "10.100.0.0/16" }
variable "azs" { default = ["us-west-2a", "us-west-2b"] }
# EKS requires minimum two AZs and 2 subnets
# https://docs.aws.amazon.com/eks/latest/userguide/network_reqs.html
variable "private_subnets" { default = [
  "10.100.1.0/24", "10.100.2.0/24"
] }
variable "public_subnets" { default = [
  "10.100.3.0/24", "10.100.4.0/24"
] }

variable "eip_count" { default = 4 }

variable "eks_cluster_name" { default = "attached-eks" }

variable "env" { default = "dev" }

variable "config-repo" { default = "config" }
