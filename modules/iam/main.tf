locals {
  common_tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "terraform"
    Module      = "iam"
  })

  irsa_roles = {
    lb_controller = {
      namespace       = "kube-system"
      service_account = "aws-load-balancer-controller"
      policy_json     = file("${path.module}/policies/lb_controller.json")
    }
    karpenter = {
      namespace       = "karpenter"
      service_account = "karpenter"
      policy_json = templatefile("${path.module}/policies/karpenter_controller.json.tpl", {
        region                  = data.aws_region.current.name
        account_id              = data.aws_caller_identity.current.account_id
        cluster_name            = var.cluster_name
        karpenter_node_role_arn = aws_iam_role.karpenter_node.arn
      })
    }
    external_dns = {
      namespace       = "external-dns"
      service_account = "external-dns"
      policy_json     = file("${path.module}/policies/external_dns.json")
    }
    vault = {
      namespace       = "vault"
      service_account = "vault"
      policy_json = templatefile("${path.module}/policies/vault_kms.json.tpl", {
        kms_key_arn = var.vault_kms_key_arn
      })
    }
  }
}

resource "aws_iam_policy" "irsa" {
  for_each = local.irsa_roles

  name_prefix = "${var.environment}-${each.key}-"
  policy      = each.value.policy_json
  tags        = local.common_tags
}

resource "aws_iam_role" "irsa" {
  for_each = local.irsa_roles

  name_prefix = "${var.environment}-${each.key}-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = var.oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${var.oidc_provider_url}:sub" = "system:serviceaccount:${each.value.namespace}:${each.value.service_account}"
          "${var.oidc_provider_url}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = merge(local.common_tags, {
    Name = "${var.environment}-${each.key}-irsa"
  })
}

resource "aws_iam_role_policy_attachment" "irsa" {
  for_each = local.irsa_roles

  role       = aws_iam_role.irsa[each.key].name
  policy_arn = aws_iam_policy.irsa[each.key].arn
}

resource "aws_iam_role" "ebs_csi" {
  name_prefix = "${var.environment}-ebs-csi-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = var.oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${var.oidc_provider_url}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
          "${var.oidc_provider_url}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = merge(local.common_tags, {
    Name = "${var.environment}-ebs-csi-irsa"
  })
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  role       = aws_iam_role.ebs_csi.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_iam_role" "karpenter_node" {
  name_prefix = "${var.environment}-karpenter-node-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = local.common_tags
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