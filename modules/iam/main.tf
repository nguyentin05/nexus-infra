locals {
  app_sa = {
    auth_service    = "system:serviceaccount:apps:auth-service"
    profile_service = "system:serviceaccount:apps:profile-service"
  }
  monitoring_sa = {
    grafana          = "system:serviceaccount:monitoring:monitoring-grafana"
    monitoring_agent = "system:serviceaccount:monitoring:nexus-monitoring-agent"
  }

  bedrock_foundation_model_id   = trimprefix(var.bedrock_model_id, "global.")
  bedrock_inference_profile_arn = "arn:aws:bedrock:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:inference-profile/${var.bedrock_model_id}"

  common_tags = merge(var.tags, {
    Module = "iam"
  })
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# AWS Load Balancer Controller
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

resource "aws_iam_role" "lb_controller" {
  name               = "${var.environment}-aws-load-balancer-controller-irsa"
  assume_role_policy = data.aws_iam_policy_document.lb_controller_assume_role.json

  tags = merge(local.common_tags, {
    Name = "aws-load-balancer-controller-irsa"
  })
}

resource "aws_iam_role_policy" "lb_controller" {
  name   = "load-balancer-controller"
  role   = aws_iam_role.lb_controller.name
  policy = file("${path.module}/policies/lb_controller.json")
}

# Vault
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

data "aws_iam_policy_document" "vault_kms" {
  statement {
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:DescribeKey",
    ]
    resources = [var.vault_kms_key_arn]
  }
}

resource "aws_iam_role" "vault" {
  name               = "${var.environment}-vault-irsa"
  assume_role_policy = data.aws_iam_policy_document.vault_assume_role.json

  tags = merge(local.common_tags, {
    Name = "vault-irsa"
  })
}

resource "aws_iam_role_policy" "vault" {
  name   = "kms-auto-unseal"
  role   = aws_iam_role.vault.name
  policy = data.aws_iam_policy_document.vault_kms.json
}

# EBS CSI
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
    Name = "ebs-csi-irsa"
  })
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  role       = aws_iam_role.ebs_csi.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

# Kyverno
data "aws_iam_policy_document" "kyverno_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:sub"
      values = [
        "system:serviceaccount:kyverno:kyverno-admission-controller",
        "system:serviceaccount:kyverno:kyverno-background-controller",
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "kyverno_ecr" {
  statement {
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    actions = [
      "ecr:BatchGetImage",
      "ecr:DescribeImages",
      "ecr:GetDownloadUrlForLayer",
    ]
    resources = [
      "arn:aws:ecr:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:repository/nexus-auth-service",
      "arn:aws:ecr:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:repository/nexus-profile-service",
    ]
  }
}

resource "aws_iam_role" "kyverno" {
  name               = "${var.environment}-kyverno-image-verifier-irsa"
  assume_role_policy = data.aws_iam_policy_document.kyverno_assume_role.json

  tags = merge(local.common_tags, {
    Name = "kyverno-image-verifier-irsa"
  })
}

resource "aws_iam_role_policy" "kyverno_ecr" {
  name   = "ecr-signature-read"
  role   = aws_iam_role.kyverno.name
  policy = data.aws_iam_policy_document.kyverno_ecr.json
}

# Grafana
data "aws_iam_policy_document" "grafana_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:sub"
      values   = [local.monitoring_sa.grafana]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "grafana_cloudwatch" {
  #checkov:skip=CKV_AWS_356:CloudWatch metric and EC2 Describe APIs do not support resource-level permissions.
  statement {
    actions = [
      "cloudwatch:DescribeAlarmHistory",
      "cloudwatch:DescribeAlarms",
      "cloudwatch:DescribeAlarmsForMetric",
      "cloudwatch:GetMetricData",
      "cloudwatch:GetMetricStatistics",
      "cloudwatch:GetInsightRuleReport",
      "cloudwatch:ListMetrics",
      "ec2:DescribeInstances",
      "ec2:DescribeRegions",
      "ec2:DescribeTags",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
      "logs:GetLogEvents",
      "logs:GetLogGroupFields",
      "logs:GetQueryResults",
      "logs:StartQuery",
      "logs:StopQuery",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role" "grafana" {
  name               = "${var.environment}-grafana-cloudwatch-irsa"
  assume_role_policy = data.aws_iam_policy_document.grafana_assume_role.json

  tags = merge(local.common_tags, {
    Name = "grafana-cloudwatch-irsa"
  })
}

resource "aws_iam_role_policy" "grafana_cloudwatch" {
  name   = "cloudwatch-read"
  role   = aws_iam_role.grafana.name
  policy = data.aws_iam_policy_document.grafana_cloudwatch.json
}

# Monitoring Agent
data "aws_iam_policy_document" "monitoring_agent_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:sub"
      values   = [local.monitoring_sa.monitoring_agent]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "monitoring_agent_bedrock" {
  statement {
    actions   = ["bedrock:InvokeModel"]
    resources = [local.bedrock_inference_profile_arn]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = [data.aws_region.current.name]
    }
  }

  statement {
    actions = ["bedrock:InvokeModel"]
    resources = [
      "arn:aws:bedrock:${data.aws_region.current.name}::foundation-model/${local.bedrock_foundation_model_id}",
    ]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = [data.aws_region.current.name]
    }

    condition {
      test     = "StringEquals"
      variable = "bedrock:InferenceProfileArn"
      values   = [local.bedrock_inference_profile_arn]
    }
  }

  statement {
    actions   = ["bedrock:InvokeModel"]
    resources = ["arn:aws:bedrock:::foundation-model/${local.bedrock_foundation_model_id}"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = ["unspecified"]
    }

    condition {
      test     = "StringEquals"
      variable = "bedrock:InferenceProfileArn"
      values   = [local.bedrock_inference_profile_arn]
    }
  }
}

resource "aws_iam_role" "monitoring_agent" {
  name               = "${var.environment}-monitoring-agent-irsa"
  assume_role_policy = data.aws_iam_policy_document.monitoring_agent_assume_role.json

  tags = merge(local.common_tags, {
    Name = "monitoring-agent-irsa"
  })
}

resource "aws_iam_role_policy" "monitoring_agent_bedrock" {
  name   = "bedrock-invoke"
  role   = aws_iam_role.monitoring_agent.name
  policy = data.aws_iam_policy_document.monitoring_agent_bedrock.json
}

# Services
#
# Auth Service
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
      values   = [local.app_sa.auth_service]
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

resource "aws_iam_role" "auth_service" {
  name               = "${var.environment}-auth-service-irsa"
  assume_role_policy = data.aws_iam_policy_document.auth_service_assume_role.json

  tags = merge(local.common_tags, {
    Name = "auth-service-irsa"
  })
}

resource "aws_iam_role_policy" "auth_service_sqs" {
  name   = "user-events-producer"
  role   = aws_iam_role.auth_service.name
  policy = data.aws_iam_policy_document.auth_service_sqs.json
}

# Profile Service
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
      values   = [local.app_sa.profile_service]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
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

resource "aws_iam_role" "profile_service" {
  name               = "${var.environment}-profile-service-irsa"
  assume_role_policy = data.aws_iam_policy_document.profile_service_assume_role.json

  tags = merge(local.common_tags, {
    Name = "profile-service-irsa"
  })
}

resource "aws_iam_role_policy" "profile_service_sqs" {
  name   = "user-events-consumer"
  role   = aws_iam_role.profile_service.name
  policy = data.aws_iam_policy_document.profile_service_sqs.json
}
