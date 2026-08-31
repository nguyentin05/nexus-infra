provider "aws" {
  region = "ap-southeast-1"
}

locals {
  github_oidc_provider_url = "https://token.actions.githubusercontent.com"

  common_tags = {
    Project   = "major"
    ManagedBy = "terraform"
  }
}

data "tls_certificate" "github_actions" {
  url = local.github_oidc_provider_url
}

resource "aws_iam_openid_connect_provider" "github_actions" {
  url             = local.github_oidc_provider_url
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github_actions.certificates[0].sha1_fingerprint]

  tags = merge(local.common_tags, {
    Name   = "github-actions"
    Module = "github-oidc"
  })
}

data "aws_iam_policy_document" "terraform_ci_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github_actions.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:nguyentin05/nexus-infra:ref:refs/heads/main"]
    }
  }
}

resource "aws_iam_role" "terraform_ci" {
  name               = "github-actions-terraform"
  assume_role_policy = data.aws_iam_policy_document.terraform_ci_assume_role.json

  tags = merge(local.common_tags, {
    Name   = "github-actions-terraform"
    Module = "github-oidc"
  })
}

resource "aws_iam_role_policy_attachment" "terraform_ci_power_user" {
  role       = aws_iam_role.terraform_ci.name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

resource "aws_iam_role_policy_attachment" "terraform_ci_iam" {
  role       = aws_iam_role.terraform_ci.name
  policy_arn = "arn:aws:iam::aws:policy/IAMFullAccess"
}

data "aws_iam_policy_document" "terraform_plan_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github_actions.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:nguyentin05/nexus-infra:pull_request"]
    }
  }
}

resource "aws_iam_role" "terraform_plan" {
  name               = "github-actions-terraform-plan"
  assume_role_policy = data.aws_iam_policy_document.terraform_plan_assume_role.json

  tags = merge(local.common_tags, {
    Name   = "github-actions-terraform-plan"
    Module = "github-oidc"
  })
}

resource "aws_iam_role_policy_attachment" "terraform_plan_read_only" {
  role       = aws_iam_role.terraform_plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}
