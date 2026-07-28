provider "aws" {
  region = "ap-southeast-1"
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

provider "cloudflare" {}

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

provider "kubectl" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_ca_data)
  load_config_file       = false

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

locals {
  environment = "dev"

  vpc_cidr = "10.0.0.0/16"

  common_tags = {
    Project     = "major"
    Environment = local.environment
    ManagedBy   = "terraform"
  }
}

module "acm" {
  source = "../../modules/acm"

  providers = {
    aws        = aws.us_east_1
    cloudflare = cloudflare
  }

  environment               = local.environment
  domain_name               = "tin-nexus.com"
  subject_alternative_names = ["*.tin-nexus.com"]
  cloudflare_zone_name      = "tin-nexus.com"

  tags = local.common_tags
}

data "aws_availability_zones" "available" {
  state = "available"
}

module "network" {
  source       = "../../modules/network"
  vpc_cidr     = local.vpc_cidr
  cluster_name = "${local.environment}-capstone-eks"
  public_subnets = {
    (data.aws_availability_zones.available.names[0]) = cidrsubnet(local.vpc_cidr, 8, 0)
    (data.aws_availability_zones.available.names[1]) = cidrsubnet(local.vpc_cidr, 8, 1)
  }
  private_subnets = {
    (data.aws_availability_zones.available.names[0]) = cidrsubnet(local.vpc_cidr, 8, 10)
    (data.aws_availability_zones.available.names[1]) = cidrsubnet(local.vpc_cidr, 8, 11)
  }

  tags = local.common_tags
}

module "kms" {
  source      = "../../modules/kms"
  environment = local.environment
  key_alias   = "vault-unseal"

  tags = local.common_tags
}

module "sqs" {
  source = "../../modules/sqs"

  environment = local.environment
  queue_name  = "${local.environment}-user-events"

  tags = local.common_tags
}

module "ecr" {
  source = "../../modules/ecr"

  environment = local.environment
  repository_names = [
    "nexus-auth-service",
    "nexus-profile-service",
  ]
  force_delete = true
  kms_key_arn  = module.kms.key_arn

  tags = local.common_tags
}

module "rds" {
  source = "../../modules/rds"

  environment                     = local.environment
  identifier                      = "${local.environment}-nexus-postgres"
  database_name                   = "nexus"
  master_username                 = "nexus_admin"
  performance_insights_kms_key_id = module.kms.key_arn
  vpc_id                          = module.network.vpc_id
  subnet_ids                      = module.network.private_subnet_ids
  allowed_security_group_ids = [
    module.network.node_security_group_id,
    module.eks.cluster_security_group_id,
  ]
  engine_version          = "18"
  parameter_group_family  = "postgres18"
  instance_class          = "db.t3.micro"
  allocated_storage       = 20
  backup_retention_period = 1
  log_retention_days      = 7
  multi_az                = false
  deletion_protection     = false
  skip_final_snapshot     = true
  apply_immediately       = true

  tags = local.common_tags
}

module "alb" {
  source = "../../modules/alb"

  environment              = local.environment
  name                     = "${local.environment}-nexus-public-alb"
  vpc_id                   = module.network.vpc_id
  public_subnet_ids        = module.network.public_subnet_ids
  target_security_group_id = module.eks.cluster_security_group_id
  target_group_name        = "${local.environment}-envoy-gateway"

  tags = local.common_tags
}

module "eks" {
  source = "../../modules/eks"

  environment                      = local.environment
  cluster_version                  = "1.36"
  private_subnet_ids               = module.network.private_subnet_ids
  system_node_instance_type        = "t3.small"
  system_node_desired_size         = 5
  system_node_max_pods             = 30
  enable_vpc_cni_prefix_delegation = true
  public_access_cidrs              = ["0.0.0.0/0"]
  cluster_admin_principal_arn      = "arn:aws:iam::065320271480:user/tin-developer"

  tags = local.common_tags
}

module "iam" {
  source = "../../modules/iam"

  environment           = local.environment
  cluster_name          = module.eks.cluster_name
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

  cluster_name             = module.eks.cluster_name
  cluster_endpoint         = module.eks.cluster_endpoint
  karpenter_irsa_role_arn  = module.iam.irsa_role_arns["karpenter"]
  karpenter_irsa_role_name = module.iam.karpenter_controller_role_name
  karpenter_node_role_name = module.iam.karpenter_node_role_name
  create_node_pool         = true

  tags = local.common_tags
}

module "waf" {
  source = "../../modules/waf"

  environment                                 = local.environment
  name                                        = "${local.environment}-nexus-public-alb-waf"
  alb_arn                                     = module.alb.load_balancer_arn
  associate_alb                               = true
  override_size_restrictions_body_to_count    = true
  override_cross_site_scripting_body_to_count = true

  tags = local.common_tags
}

module "cloudfront" {
  source = "../../modules/cloudfront"

  environment        = local.environment
  name               = "dev-nexus-api-cdn"
  origin_domain_name = module.alb.dns_name
  aliases            = ["api.tin-nexus.com"]
  certificate_arn    = module.acm.certificate_arn

  tags = local.common_tags
}
