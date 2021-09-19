output "test_topology" {
  description = "The topology file for crud test"
  value = templatefile("${path.module}/test_topology.tpl", {
    region              = "${var.region}"
    iam_role_arn        = module.iam.role_arn
    role_session_name   = "${var.dev_workspace}-session"
    control_subnet_ids  = module.vpc.private_subnets
    nodepool_subnet_ids = module.vpc.private_subnets
    load_balancer_subnet_ids = concat(module.vpc.public_subnets,
    module.vpc.private_subnets)
    bastion_subnet_id               = module.vpc.public_subnets[0]
    vpc_id                          = module.vpc.vpc_id
    database_encryption_kms_key_arn = module.kms.database_encryption_kms_key_arn
    ebs_encryption_kms_key_arn      = module.kms.ebs_encryption_kms_key_arn
    ssh_key_pair_name               = module.vpc.ec2_key_pair
    iam_instance_profile_name       = module.vpc.cp_instance_profile_id
    bastion_address                 = module.bastion.public_dns
    ssh_private_key_path            = var.ssh_private_key_path
    proxy_secret_arn                = var.create_proxy ? module.proxy[0].secret_arn : ""
    proxy_secret_version            = var.create_proxy ? module.proxy[0].secret_version : ""
    proxy_access_sg_id              = var.create_proxy ? module.proxy[0].proxy_access_sg_id : ""
  })
}

output "create_cluster" {
  description = "The create cluster request"
  value = templatefile("${path.module}/create_cluster.tpl", {
    owner                           = "${var.owner}"
    vpc_id                          = module.vpc.vpc_id
    subnet_ids                      = module.vpc.private_subnets
    public_elb_subnet_ids           = module.vpc.public_subnets
    security_group_id               = module.vpc.network_security_group
    region                          = "${var.region}"
    ssh_key_pair_name               = module.vpc.ec2_key_pair
    iam_instance_profile_name       = module.vpc.cp_instance_profile_id
    database_encryption_kms_key_arn = module.kms.database_encryption_kms_key_arn
    ebs_encryption_kms_key_arn      = module.kms.ebs_encryption_kms_key_arn
    iam_role_arn                    = module.iam.role_arn
    role_session_name               = "${var.dev_workspace}-session"
    proxy_secret_arn                = var.create_proxy ? module.proxy[0].secret_arn : ""
    proxy_secret_version            = var.create_proxy ? module.proxy[0].secret_version : ""
    proxy_access_sg_id              = var.create_proxy ? module.proxy[0].proxy_access_sg_id : ""
  })
}

output "update_cluster" {
  description = "The update cluster request"
  value = templatefile("${path.module}/update_cluster.tpl", {
    owner = "${var.owner}"
  })
}

output "create_nodepool" {
  description = "The create nodepool request"
  value = templatefile("${path.module}/create_nodepool.tpl", {
    owner                     = "${var.owner}"
    subnet_id                 = module.vpc.private_subnets[0]
    security_group_id         = module.vpc.network_security_group
    iam_instance_profile_name = module.vpc.np_instance_profile_id
    ssh_key_pair_name         = module.vpc.ec2_key_pair
    proxy_secret_arn          = var.create_proxy ? module.proxy[0].secret_arn : ""
    proxy_secret_version      = var.create_proxy ? module.proxy[0].secret_version : ""
    proxy_access_sg_id        = var.create_proxy ? module.proxy[0].proxy_access_sg_id : ""
  })
}

output "create_aws_envs" {
  description = "create aws environment vars"
  value = templatefile("${path.module}/create_aws_envs.tpl", {
    aws_region                ="${var.region}" 
    vpc_id                    = module.vpc.vpc_id
    cluster_name              ="${var.owner}-anthos-aws2"
    nodepool_name             ="${var.owner}-anthos-aws2"
    nodepool_subnet_id        = module.vpc.private_subnets[0]
    private_subnet_ids        = module.vpc.private_subnets                            
    control_plane_profile     = module.vpc.cp_instance_profile_id
    ssh_key_pair_name         = module.vpc.ec2_key_pair 
    public_subnet_ids         = module.vpc.public_subnets
    dbs_kms_key_arn           = module.kms.database_encryption_kms_key_arn
    api_role_arn              = module.iam.role_arn
    nodepool_profile          = module.vpc.np_instance_profile_id
    bastion_address           = module.bastion.public_dns
    ssh_private_key_path      = var.ssh_private_key_path
  })
}
