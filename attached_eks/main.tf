

module "vpc" {
  source = "./vpc/"

  name              = var.name
  cidr              = var.cidr
  azs               = var.azs
  private_subnets   = var.private_subnets
  public_subnets    = var.public_subnets
  eks_cluster_name = var.eks_cluster_name
  eip_count         = var.eip_count

}


module "eks" {
  source           = "./eks/"
  eks_cluster_name = var.eks_cluster_name
  vpc_id           = module.vpc.id
  private_subnets  = module.vpc.private_subnets
  project_id       = var.project_id
  env              = var.env
  repo_url         = "https://github.com/GoogleCloudPlatform/anthos-config-management-samples.git"
}

