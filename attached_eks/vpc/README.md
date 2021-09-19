# Terraform AWS VPC Module
This module builds a AWS VPC. This module is built on top of the official AWS VPC module which can be found [here](https://github.com/terraform-aws-modules/terraform-aws-vpc). 

## Compatibility
This module is meant for use with Terraform 0.12.

## Usage
Following example is taken from the [/infrastructure/prod/aws/vpc](/infrastructure/prod/aws/vpc) folder.
```bash
module "prod_vpc" {
  source = "../../../../platform_admins/shared_terraform_modules/aws/vpc/"
  name              = var.name
  cidr              = var.cidr
  azs               = var.azs
  private_subnets   = var.private_subnets
  public_subnets    = var.public_subnets
  eks1_cluster_name = var.eks1_cluster_name
  eks2_cluster_name = var.eks2_cluster_name
  eip_count = var.eip_count
}
```

## Inputs
| **Name** | **Description** | **Type** | **Default** | **Required** |
| ---      | ---             | ---      | ---         | ---          |
| `name` | Name of the VPC | string | "" | yes |
| `cidr` | CIDR network range | string | "" | yes |
| `azs` | Availability Zone | string | "" | yes |
| `private_subnets` | Names, regions and IP addresses of all private subnets in the VPC | list(object) | "" | yes |
| `public_subnets` | Names, regions and IP addresses of all public subnets in the VPC | list(object) | "" | yes |
| `eks1_cluster_name` | EKS cluster name 1 | string | "" | yes |
| `eks2_cluster_name` | EKS cluster name 2 | string | "" | yes |
| `eip_count` | Elastic IP's assigned | string | "" | yes |

## Outputs
| **Name** | **Description** | 
| ---      | ---             | 
| `id` | Prod VPC ID | 
| `network_name` | VPC network name |
| `private_subnets` | Outputs of the corresponding private subnets. |
| `public_subnets` | Outputs of the corresponding public subnets. |
| `eip_ids` | The ID's for the elastic IP's |
| `eip_public_ips` | The IP's for the public elastic IP's |

## Requirements
### Software
- [Terraform](https://www.terraform.io/downloads.html) ~> 0.12.6
- [Terraform Provider for AWS](https://github.com/terraform-providers/terraform-provider-aws) ~> 2.19
- [gcloud](https://cloud.google.com/sdk/gcloud/) >243.0.0

