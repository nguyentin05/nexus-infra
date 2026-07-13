data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_iam_openid_connect_provider" "github_actions" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
  ]

  tags = {
    Project     = "capstone"
    Environment = "dev"
    ManagedBy   = "terraform"
    Module      = "github-actions"
  }
}

data "aws_iam_policy_document" "github_actions_assume_role" {
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
      values   = ["repo:nguyentin05/nexus-gitops:ref:refs/heads/main"]
    }
  }
}

data "aws_iam_policy_document" "github_actions_eks" {
  statement {
    actions = ["eks:DescribeCluster"]
    resources = [
      "arn:aws:eks:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:cluster/${module.eks.cluster_name}",
    ]
  }
}

resource "aws_iam_role" "github_actions_gitops" {
  name               = "dev-github-actions-gitops"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json

  tags = {
    Project     = "capstone"
    Environment = "dev"
    ManagedBy   = "terraform"
    Module      = "github-actions"
  }
}

resource "aws_iam_role_policy" "github_actions_eks" {
  name   = "eks-describe-cluster"
  role   = aws_iam_role.github_actions_gitops.id
  policy = data.aws_iam_policy_document.github_actions_eks.json
}

resource "aws_eks_access_entry" "github_actions_gitops" {
  cluster_name      = module.eks.cluster_name
  principal_arn     = aws_iam_role.github_actions_gitops.arn
  kubernetes_groups = ["nexus-gitops-secret-sync"]
  type              = "STANDARD"
}

output "github_actions_role_arn" {
  description = "IAM role ARN used by nexus-gitops GitHub Actions workflows"
  value       = aws_iam_role.github_actions_gitops.arn
}
