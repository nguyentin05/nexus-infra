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
  project          = "major"
  environment      = "dev"
  cluster_name     = "${local.environment}-${local.project}-eks"
  bedrock_model_id = "global.amazon.nova-2-lite-v1:0"

  vpc_cidr = "10.0.0.0/16"

  common_tags = {
    Project     = local.project
    Environment = local.environment
    ManagedBy   = "terraform"
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_acm_certificate" "api" {
  provider    = aws.us_east_1
  domain      = "tin-nexus.com"
  statuses    = ["ISSUED"]
  most_recent = true
}

module "network" {
  source = "../../modules/network"

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
  engine_version                  = "18"
  parameter_group_family          = "postgres18"
  instance_class                  = "db.t3.micro"
  allocated_storage               = 20
  backup_retention_period         = 1
  log_retention_days              = 7
  multi_az                        = false
  deletion_protection             = false
  skip_final_snapshot             = true
  apply_immediately               = true

  tags = local.common_tags
}

module "nlb" {
  source = "../../modules/nlb"

  environment              = local.environment
  name                     = "${local.environment}-nexus-public-nlb"
  vpc_id                   = module.network.vpc_id
  public_subnet_ids        = module.network.public_subnet_ids
  target_security_group_id = module.network.node_security_group_id
  target_group_name        = "${local.environment}-envoy-gateway-nlb"

  tags = local.common_tags
}

module "eks" {
  source = "../../modules/eks"

  environment                      = local.environment
  name                             = "${local.project}-eks"
  cluster_version                  = "1.36"
  private_subnet_ids               = module.network.private_subnet_ids
  node_security_group_id           = module.network.node_security_group_id
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
  oidc_provider_arn     = module.eks.oidc_provider_arn
  oidc_provider_url     = module.eks.oidc_provider_url
  vault_kms_key_arn     = module.kms.key_arn
  user_events_queue_arn = module.sqs.queue_arn
  bedrock_model_id      = local.bedrock_model_id

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

  cluster_name           = module.eks.cluster_name
  cluster_endpoint       = module.eks.cluster_endpoint
  oidc_provider_arn      = module.eks.oidc_provider_arn
  create_node_pool       = true
  instance_types         = ["t3.small"]
  node_pool_cpu_limit    = 2
  node_pool_memory_limit = "2Gi"
  node_pool_node_limit   = 1

  tags = local.common_tags
}

module "cloudfront_waf" {
  source = "../../modules/waf"

  providers = {
    aws = aws.us_east_1
  }

  environment                                 = local.environment
  name                                        = "${local.environment}-nexus-cloudfront-waf"
  override_hosting_provider_ip_list_to_count  = true
  override_size_restrictions_body_to_count    = true
  override_cross_site_scripting_body_to_count = true

  tags = local.common_tags
}

module "cloudfront" {
  source = "../../modules/cloudfront"

  name               = "dev-nexus-api-cdn"
  origin_domain_name = module.nlb.dns_name
  aliases            = ["api.tin-nexus.com"]
  certificate_arn    = data.aws_acm_certificate.api.arn
  web_acl_id         = module.cloudfront_waf.web_acl_arn

  tags = local.common_tags
}
