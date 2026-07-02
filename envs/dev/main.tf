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

module "kms" {
  source = "../../modules/kms"

  environment = "dev"
  key_alias   = "vault-unseal"

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
  system_node_desired_size    = 2
  public_access_cidrs         = ["0.0.0.0/0"]
  cluster_admin_principal_arn = "arn:aws:iam::065320271480:user/tin-developer"

  tags = { Project = "capstone" }
}

module "iam" {
  source = "../../modules/iam"

  environment       = "dev"
  cluster_name      = module.eks.cluster_name
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url
  vault_kms_key_arn = module.kms.key_arn

  tags = { Project = "capstone" }
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