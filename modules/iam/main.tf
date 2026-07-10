locals {
  common_tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "terraform"
    Module      = "iam"
  })
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_iam_policy_document" "lb_controller_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "lb_controller" {
  name_prefix = "${var.environment}-lb_controller-"
  policy      = file("${path.module}/policies/lb_controller.json")
  tags        = local.common_tags
}

resource "aws_iam_role" "lb_controller" {
  name               = "${var.environment}-aws-load-balancer-controller-irsa"
  assume_role_policy = data.aws_iam_policy_document.lb_controller_assume_role.json

  tags = merge(local.common_tags, {
    Name = "${var.environment}-aws-load-balancer-controller-irsa"
  })
}

resource "aws_iam_role_policy_attachment" "lb_controller" {
  role       = aws_iam_role.lb_controller.name
  policy_arn = aws_iam_policy.lb_controller.arn
}

data "aws_iam_policy_document" "karpenter_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:sub"
      values   = ["system:serviceaccount:karpenter:karpenter"]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "karpenter" {
  name_prefix = "${var.environment}-karpenter-"
  policy = templatefile("${path.module}/policies/karpenter_controller.json.tpl", {
    region                  = data.aws_region.current.name
    account_id              = data.aws_caller_identity.current.account_id
    cluster_name            = var.cluster_name
    karpenter_node_role_arn = aws_iam_role.karpenter_node.arn
  })
  tags = local.common_tags
}

resource "aws_iam_role" "karpenter" {
  name_prefix        = "${var.environment}-karpenter-"
  assume_role_policy = data.aws_iam_policy_document.karpenter_assume_role.json

  tags = merge(local.common_tags, {
    Name = "${var.environment}-karpenter-irsa"
  })
}

resource "aws_iam_role_policy_attachment" "karpenter" {
  role       = aws_iam_role.karpenter.name
  policy_arn = aws_iam_policy.karpenter.arn
}

data "aws_iam_policy_document" "external_dns_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:sub"
      values   = ["system:serviceaccount:external-dns:external-dns"]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "external_dns" {
  name_prefix = "${var.environment}-external_dns-"
  policy      = file("${path.module}/policies/external_dns.json")
  tags        = local.common_tags
}

resource "aws_iam_role" "external_dns" {
  name_prefix        = "${var.environment}-external_dns-"
  assume_role_policy = data.aws_iam_policy_document.external_dns_assume_role.json

  tags = merge(local.common_tags, {
    Name = "${var.environment}-external_dns-irsa"
  })
}

resource "aws_iam_role_policy_attachment" "external_dns" {
  role       = aws_iam_role.external_dns.name
  policy_arn = aws_iam_policy.external_dns.arn
}

data "aws_iam_policy_document" "vault_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:sub"
      values   = ["system:serviceaccount:vault:vault"]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "vault" {
  name_prefix = "${var.environment}-vault-"
  policy = templatefile("${path.module}/policies/vault_kms.json.tpl", {
    kms_key_arn = var.vault_kms_key_arn
  })
  tags = local.common_tags
}

resource "aws_iam_role" "vault" {
  name               = "${var.environment}-vault-irsa"
  assume_role_policy = data.aws_iam_policy_document.vault_assume_role.json

  tags = merge(local.common_tags, {
    Name = "${var.environment}-vault-irsa"
  })
}

resource "aws_iam_role_policy_attachment" "vault" {
  role       = aws_iam_role.vault.name
  policy_arn = aws_iam_policy.vault.arn
}

data "aws_iam_policy_document" "ebs_csi_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ebs_csi" {
  name_prefix        = "${var.environment}-ebs-csi-"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_assume_role.json

  tags = merge(local.common_tags, {
    Name = "${var.environment}-ebs-csi-irsa"
  })
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  role       = aws_iam_role.ebs_csi.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

data "aws_iam_policy_document" "karpenter_node_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "karpenter_node" {
  name_prefix        = "${var.environment}-karpenter-node-"
  assume_role_policy = data.aws_iam_policy_document.karpenter_node_assume_role.json
  tags               = local.common_tags
}

resource "aws_iam_role_policy_attachment" "karpenter_node_worker" {
  role       = aws_iam_role.karpenter_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "karpenter_node_cni" {
  role       = aws_iam_role.karpenter_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "karpenter_node_ecr" {
  role       = aws_iam_role.karpenter_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "karpenter_node_ssm" {
  role       = aws_iam_role.karpenter_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
locals {
  app_service_accounts = {
    auth_service    = "system:serviceaccount:apps:auth-service"
    profile_service = "system:serviceaccount:apps:profile-service"
  }
}

data "aws_iam_policy_document" "auth_service_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:sub"
      values   = [local.app_service_accounts.auth_service]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "profile_service_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:sub"
      values   = [local.app_service_accounts.profile_service]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "auth_service_sqs" {
  statement {
    actions = [
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl",
      "sqs:SendMessage",
    ]
    resources = [var.user_events_queue_arn]
  }
}

data "aws_iam_policy_document" "profile_service_sqs" {
  statement {
    actions = [
      "sqs:ChangeMessageVisibility",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl",
      "sqs:ReceiveMessage",
    ]
    resources = [var.user_events_queue_arn]
  }
}

resource "aws_iam_policy" "auth_service_sqs" {
  name   = "${var.environment}-auth-service-sqs"
  policy = data.aws_iam_policy_document.auth_service_sqs.json
  tags   = local.common_tags
}

resource "aws_iam_policy" "profile_service_sqs" {
  name   = "${var.environment}-profile-service-sqs"
  policy = data.aws_iam_policy_document.profile_service_sqs.json
  tags   = local.common_tags
}

resource "aws_iam_role" "auth_service" {
  name               = "${var.environment}-auth-service-irsa"
  assume_role_policy = data.aws_iam_policy_document.auth_service_assume_role.json

  tags = merge(local.common_tags, {
    Name = "${var.environment}-auth-service-irsa"
  })
}

resource "aws_iam_role" "profile_service" {
  name               = "${var.environment}-profile-service-irsa"
  assume_role_policy = data.aws_iam_policy_document.profile_service_assume_role.json

  tags = merge(local.common_tags, {
    Name = "${var.environment}-profile-service-irsa"
  })
}

resource "aws_iam_role_policy_attachment" "auth_service_sqs" {
  role       = aws_iam_role.auth_service.name
  policy_arn = aws_iam_policy.auth_service_sqs.arn
}

resource "aws_iam_role_policy_attachment" "profile_service_sqs" {
  role       = aws_iam_role.profile_service.name
  policy_arn = aws_iam_policy.profile_service_sqs.arn
}
