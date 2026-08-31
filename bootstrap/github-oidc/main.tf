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

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "terraform_ci_iam" {
  statement {
    sid = "ManageTerraformIAMResources"
    actions = [
      "iam:AddClientIDToOpenIDConnectProvider",
      "iam:AddRoleToInstanceProfile",
      "iam:AttachRolePolicy",
      "iam:CreateInstanceProfile",
      "iam:CreateOpenIDConnectProvider",
      "iam:CreatePolicy",
      "iam:CreatePolicyVersion",
      "iam:CreateRole",
      "iam:DeleteInstanceProfile",
      "iam:DeleteOpenIDConnectProvider",
      "iam:DeletePolicy",
      "iam:DeletePolicyVersion",
      "iam:DeleteRole",
      "iam:DeleteRolePolicy",
      "iam:DetachRolePolicy",
      "iam:GetInstanceProfile",
      "iam:GetOpenIDConnectProvider",
      "iam:GetPolicy",
      "iam:GetPolicyVersion",
      "iam:GetRole",
      "iam:GetRolePolicy",
      "iam:ListAttachedRolePolicies",
      "iam:ListInstanceProfilesForRole",
      "iam:ListPolicyVersions",
      "iam:ListRolePolicies",
      "iam:PassRole",
      "iam:PutRolePolicy",
      "iam:RemoveClientIDFromOpenIDConnectProvider",
      "iam:RemoveRoleFromInstanceProfile",
      "iam:TagInstanceProfile",
      "iam:TagOpenIDConnectProvider",
      "iam:TagPolicy",
      "iam:TagRole",
      "iam:UntagInstanceProfile",
      "iam:UntagOpenIDConnectProvider",
      "iam:UntagPolicy",
      "iam:UntagRole",
      "iam:UpdateAssumeRolePolicy",
      "iam:UpdateOpenIDConnectProviderThumbprint",
      "iam:UpdateRole",
      "iam:UpdateRoleDescription",
    ]
    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:instance-profile/*",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/*",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/*",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/*",
    ]
  }

  statement {
    sid = "ReadTerraformIAMResources"
    actions = [
      "iam:ListOpenIDConnectProviders",
      "iam:ListRoles",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "terraform_ci_iam" {
  name   = "terraform-iam-management"
  role   = aws_iam_role.terraform_ci.name
  policy = data.aws_iam_policy_document.terraform_ci_iam.json
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
