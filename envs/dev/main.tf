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

module "acm" {
  source = "../../modules/acm"

  providers = {
    aws        = aws.us_east_1
    cloudflare = cloudflare
  }

  environment               = "dev"
  domain_name               = "tin-nexus.com"
  subject_alternative_names = ["*.tin-nexus.com"]
  cloudflare_zone_name      = "tin-nexus.com"

  tags = { Project = "capstone" }
}

module "network" {
  source = "../../modules/network"

  name                 = "dev-capstone"
  environment          = "dev"
  vpc_cidr             = "10.0.0.0/16"
  azs                  = ["ap-southeast-1a", "ap-southeast-1b"]
  public_subnet_cidrs  = ["10.0.0.0/24", "10.0.1.0/24"]
  private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]
  single_nat_gateway   = true
  cluster_name         = "dev-capstone-eks"

  tags = { Project = "capstone" }
}

module "sqs" {
  source = "../../modules/sqs"

  environment = "dev"
  queue_name  = "dev-user-events"

  tags = { Project = "capstone" }
}

module "kms" {
  source = "../../modules/kms"

  environment = "dev"
  key_alias   = "vault-unseal"

  tags = { Project = "capstone" }
}

module "rds" {
  source = "../../modules/rds"

  environment     = "dev"
  identifier      = "dev-nexus-postgres"
  database_name   = "nexus"
  master_username = "nexus_admin"
  vpc_id          = module.network.vpc_id
  subnet_ids      = module.network.private_subnet_ids
  allowed_security_group_ids = [
    module.network.node_security_group_id,
    module.eks.cluster_security_group_id,
  ]
  instance_class          = "db.t3.micro"
  allocated_storage       = 20
  backup_retention_period = 1
  multi_az                = false
  deletion_protection     = false
  skip_final_snapshot     = true
  apply_immediately       = true

  tags = { Project = "capstone" }
}

module "alb" {
  source = "../../modules/alb"

  environment              = "dev"
  name                     = "dev-nexus-public-alb"
  vpc_id                   = module.network.vpc_id
  public_subnet_ids        = module.network.public_subnet_ids
  target_security_group_id = module.eks.cluster_security_group_id
  target_group_name        = "dev-envoy-gateway"

  tags = { Project = "capstone" }
}

module "eks" {
  source = "../../modules/eks"

  environment                 = "dev"
  cluster_version             = "1.36"
  vpc_id                      = module.network.vpc_id
  private_subnet_ids          = module.network.private_subnet_ids
  public_subnet_ids           = module.network.public_subnet_ids
  system_node_instance_type   = "t3.small"
  system_node_desired_size    = 4
  public_access_cidrs         = ["0.0.0.0/0"]
  cluster_admin_principal_arn = "arn:aws:iam::065320271480:user/tin-developer"

  tags = { Project = "capstone" }
}

module "iam" {
  source = "../../modules/iam"

  environment           = "dev"
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

  environment              = "dev"
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

  environment                                 = "dev"
  name                                        = "dev-nexus-public-alb-waf"
  alb_arn                                     = module.alb.load_balancer_arn
  associate_alb                               = true
  override_size_restrictions_body_to_count    = true
  override_cross_site_scripting_body_to_count = true

  tags = { Project = "capstone" }
}

module "cloudfront" {
  source = "../../modules/cloudfront"

  environment        = "dev"
  name               = "dev-nexus-api-cdn"
  origin_domain_name = module.alb.dns_name
  aliases            = ["api.tin-nexus.com"]
  certificate_arn    = module.acm.certificate_arn

  tags = { Project = "capstone" }
}
