/**
 * Copyright 2020 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

provider "kubernetes" {
  host                   = data.aws_eks_cluster.eks_cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks_cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.eks_cluster.token
  load_config_file       = false
  version                = "~> 1.11"
}

data "aws_eks_cluster" "eks_cluster" {
  name = module.eks.cluster_id
}

data "aws_eks_cluster_auth" "eks_cluster" {
  name = module.eks.cluster_id
}

resource "aws_security_group" "worker_group_mgmt_one" {
  name_prefix = "worker_group_mgmt_one"
  vpc_id      = var.vpc_id

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"

    cidr_blocks = [
      "10.0.0.0/8",
    ]
  }
}

resource "aws_security_group" "worker_group_mgmt_two" {
  name_prefix = "worker_group_mgmt_two"
  vpc_id      = var.vpc_id

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"

    cidr_blocks = [
      "192.168.0.0/16",
    ]
  }
}

resource "aws_security_group" "all_worker_mgmt" {
  name_prefix = "all_worker_management"
  vpc_id      = var.vpc_id

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"

    cidr_blocks = [
      "10.0.0.0/8",
      "172.16.0.0/12",
      "192.168.0.0/16",
    ]
  }
}

module "eks" {
  source          = "github.com/terraform-aws-modules/terraform-aws-eks?ref=v14.0.0"
  cluster_name    = var.eks_cluster_name
  cluster_version = "1.18"
  subnets         = var.private_subnets

  tags = {
    Environment = var.env
  }

  vpc_id = var.vpc_id

# lack of gp3 support in launch config
# https://github.com/terraform-aws-modules/terraform-aws-eks/issues/1205#issuecomment-769695873
  workers_group_defaults = {
  	root_volume_type = "gp2"
  }
  
  worker_groups = [
    {
      name                          = "worker-group-1"
      instance_type                 = "t3.xlarge"
      asg_desired_capacity          = 3
      additional_security_group_ids = [aws_security_group.worker_group_mgmt_one.id]
    },
  ]

  worker_additional_security_group_ids = [aws_security_group.all_worker_mgmt.id]
  map_roles                            = var.map_roles
  map_users                            = var.map_users
  map_accounts                         = var.map_accounts
}

resource "null_resource" "exec_eks_kubeconfig" {
  count=1
  provisioner "local-exec" {
    interpreter = ["bash", "-exc"]
    command     = "${path.module}/eks_kubeconfig.sh"
    environment = {
      PROJECT_ID = var.project_id
      EKS        = module.eks.cluster_id
      ENV        = var.env
    }
  }

  triggers = {
    script_sha1 = sha1(file("${path.module}/eks_kubeconfig.sh"))
  }
  depends_on = [
    module.eks,
  ]
}

resource "null_resource" "exec_eks_acm" {
  count=1
  provisioner "local-exec" {
    interpreter = ["bash", "-exc"]
    command     = "${path.module}/eks_acm.sh"
    environment = {
      EKS_CLUSTER = module.eks.cluster_id
      PROJECT_ID  = var.project_id
      REPO_URL    = var.repo_url
      SYNC_BRANCH = var.sync_branch
    }
  }
  triggers = {
    script_sha1 = sha1(file("${path.module}/eks_acm.sh"))
  }
  depends_on = [
    null_resource.exec_eks_kubeconfig,
  ]
}

resource "null_resource" "exec_eks_lm" {
  count=1
  provisioner "local-exec" {
    interpreter = ["bash", "-exc"]
    command     = "${path.module}/eks_lm.sh"
    environment = {
      EKS_CLUSTER = module.eks.cluster_id
      PROJECT_ID  = var.project_id
    }
  }
  triggers = {
    script_sha1 = sha1(file("${path.module}/eks_lm.sh"))
  }
  depends_on = [
    null_resource.exec_eks_kubeconfig,
  ]
}
