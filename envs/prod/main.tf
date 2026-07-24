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

module "network" {
  source = "../../modules/network"

  environment          = "prod"
  vpc_cidr             = "10.1.0.0/16"
  azs                  = ["ap-southeast-1a", "ap-southeast-1b"]
  public_subnet_cidrs  = ["10.1.0.0/24", "10.1.1.0/24"]
  private_subnet_cidrs = ["10.1.10.0/24", "10.1.11.0/24"]
  single_nat_gateway   = false
  cluster_name         = "prod-capstone-eks"

  tags = { Project = "capstone" }
}

module "sqs" {
  source = "../../modules/sqs"

  environment = "prod"
  queue_name  = "prod-user-events"

  tags = { Project = "capstone" }
}

module "kms" {
  source = "../../modules/kms"

  environment = "prod"
  key_alias   = "vault-unseal"

  tags = { Project = "capstone" }
}

module "rds" {
  source = "../../modules/rds"

  environment                     = "prod"
  identifier                      = "prod-nexus-postgres"
  database_name                   = "nexus"
  master_username                 = "nexus_admin"
  performance_insights_kms_key_id = module.kms.key_arn
  vpc_id                          = module.network.vpc_id
  subnet_ids                      = module.network.private_subnet_ids
  allowed_security_group_ids      = [module.network.node_security_group_id]
  instance_class                  = "db.m6g.large"
  allocated_storage               = 20
  backup_retention_period         = 7
  multi_az                        = true
  deletion_protection             = true
  skip_final_snapshot             = false
  apply_immediately               = false

  tags = { Project = "capstone" }
}

module "eks" {
  source = "../../modules/eks"

  environment               = "prod"
  cluster_version           = "1.36"
  private_subnet_ids        = module.network.private_subnet_ids
  system_node_instance_type = "t3.small"
  system_node_desired_size  = 2
  public_access_cidrs       = var.public_access_cidrs

  tags = { Project = "capstone" }
}

module "iam" {
  source = "../../modules/iam"

  environment           = "prod"
  cluster_name          = module.eks.cluster_name
  oidc_provider_arn     = module.eks.oidc_provider_arn
  oidc_provider_url     = module.eks.oidc_provider_url
  vault_kms_key_arn     = module.kms.key_arn
  user_events_queue_arn = module.sqs.queue_arn

  tags = { Project = "capstone" }
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

  environment              = "prod"
  cluster_name             = module.eks.cluster_name
  cluster_endpoint         = module.eks.cluster_endpoint
  karpenter_irsa_role_arn  = module.iam.irsa_role_arns["karpenter"]
  karpenter_node_role_name = module.iam.karpenter_node_role_name
  private_subnet_ids       = module.network.private_subnet_ids
  node_security_group_id   = module.network.node_security_group_id

  instance_families = ["m5", "m6i", "c5"]
  instance_sizes    = ["large", "xlarge"]
}

module "waf" {
  source = "../../modules/waf"

  environment = "prod"
  name        = "prod-nexus-public-alb-waf"

  tags = { Project = "capstone" }
}
