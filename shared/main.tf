provider "aws" {
  region = "ap-southeast-1"
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

provider "cloudflare" {}

locals {
  domain_name = "tin-nexus.com"
  common_tags = {
    Project   = "major"
    ManagedBy = "terraform"
  }
}

data "aws_iam_openid_connect_provider" "github_actions" {
  url = "https://token.actions.githubusercontent.com"
}

module "ecr_kms" {
  source = "../modules/kms"

  key_alias = "nexus-ecr"
  tags      = local.common_tags
}

module "ecr" {
  source = "../modules/ecr"

  repository_names = [
    "nexus-auth-service",
    "nexus-profile-service",
  ]
  kms_key_arn = module.ecr_kms.key_arn
  tags        = local.common_tags
}

module "acm" {
  source = "../modules/acm"

  providers = {
    aws        = aws.us_east_1
    cloudflare = cloudflare
  }

  domain_name               = local.domain_name
  subject_alternative_names = ["*.${local.domain_name}"]
  cloudflare_zone_name      = local.domain_name

  tags = local.common_tags
}

data "aws_iam_policy_document" "app_release_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github_actions.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:nguyentin05/nexus-app:ref:refs/heads/main"]
    }
  }
}

data "aws_iam_policy_document" "app_release_ecr" {
  statement {
    sid       = "GetAuthorizationToken"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid = "PublishAppImages"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:DescribeRepositories",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]
    resources = values(module.ecr.repository_arns)
  }
}

resource "aws_iam_role" "app_release" {
  name               = "github-actions-app-release"
  assume_role_policy = data.aws_iam_policy_document.app_release_assume_role.json

  tags = merge(local.common_tags, {
    Name   = "github-actions-app-release"
    Module = "github-actions"
  })
}

resource "aws_iam_role_policy" "app_release_ecr" {
  name   = "publish-app-images"
  role   = aws_iam_role.app_release.id
  policy = data.aws_iam_policy_document.app_release_ecr.json
}
