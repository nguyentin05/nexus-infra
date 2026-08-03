provider "aws" {
  region = "ap-southeast-1"
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_ca_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_ca_data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}

locals {
  project      = "major"
  environment  = "prod"
  cluster_name = "${local.environment}-${local.project}-eks"

  vpc_cidr = "10.1.0.0/16"

  common_tags = {
    Project     = local.project
    Environment = local.environment
    ManagedBy   = "terraform"
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

module "network" {
  source       = "../../modules/network"
  environment  = local.environment
  vpc_cidr     = local.vpc_cidr
  cluster_name = local.cluster_name
  public_subnets = {
    (data.aws_availability_zones.available.names[0]) = cidrsubnet(local.vpc_cidr, 8, 0)
    (data.aws_availability_zones.available.names[1]) = cidrsubnet(local.vpc_cidr, 8, 1)
  }
  private_subnets = {
    (data.aws_availability_zones.available.names[0]) = cidrsubnet(local.vpc_cidr, 8, 10)
    (data.aws_availability_zones.available.names[1]) = cidrsubnet(local.vpc_cidr, 8, 11)
  }
  database_subnets = {
    (data.aws_availability_zones.available.names[0]) = cidrsubnet(local.vpc_cidr, 8, 20)
    (data.aws_availability_zones.available.names[1]) = cidrsubnet(local.vpc_cidr, 8, 21)
  }

  tags = local.common_tags
}

module "kms" {
  source = "../../modules/kms"

  environment = local.environment
  key_alias   = "vault-unseal"

  tags = local.common_tags
}

module "sqs" {
  source = "../../modules/sqs"

  environment = local.environment
  queue_name  = "user-events"

  tags = local.common_tags
}


module "rds" {
  source = "../../modules/rds"

  identifier                      = "${local.environment}-nexus-postgres"
  database_name                   = "nexus"
  master_username                 = "nexus_admin"
  performance_insights_kms_key_id = module.kms.key_arn
  vpc_id                          = module.network.vpc_id
  subnet_ids                      = module.network.database_subnet_ids
  allowed_security_group_id       = module.network.node_security_group_id
  instance_class                  = "db.m6g.large"
  allocated_storage               = 20
  backup_retention_period         = 7
  multi_az                        = true
  deletion_protection             = true
  skip_final_snapshot             = false
  apply_immediately               = false

  tags = local.common_tags
}

module "eks" {
  source = "../../modules/eks"

  environment               = local.environment
  name                      = "${local.project}-eks"
  cluster_version           = "1.36"
  private_subnet_ids        = module.network.private_subnet_ids
  node_security_group_id    = module.network.node_security_group_id
  system_node_instance_type = "t3.small"
  system_node_desired_size  = 2
  public_access_cidrs       = var.public_access_cidrs

  tags = local.common_tags
}

module "iam" {
  source = "../../modules/iam"

  environment           = local.environment
  oidc_provider_arn     = module.eks.oidc_provider_arn
  oidc_provider_url     = module.eks.oidc_provider_url
  vault_kms_key_arn     = module.kms.key_arn
  user_events_queue_arn = module.sqs.queue_arn

  tags = local.common_tags
}

resource "aws_eks_addon" "ebs_csi" {
  cluster_name             = module.eks.cluster_name
  addon_name               = "aws-ebs-csi-driver"
  service_account_role_arn = module.iam.ebs_csi_role_arn

  depends_on = [module.eks, module.iam]
}

module "karpenter" {
  source = "../../modules/karpenter"

  depends_on = [module.eks]

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  oidc_provider_arn = module.eks.oidc_provider_arn
  instance_types    = ["t3.small"]
  tags              = local.common_tags
}

module "waf" {
  source = "../../modules/waf"

  environment = local.environment
  name        = "${local.environment}-nexus-public-alb-waf"

  tags = local.common_tags
}
