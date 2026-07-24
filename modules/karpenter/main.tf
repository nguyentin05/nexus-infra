locals {
  common_tags = merge(var.tags, {
    ManagedBy = "terraform"
    Module    = "karpenter"
  })

  interruption_events = {
    health_event = {
      name        = "HealthEvent"
      description = "Karpenter interrupt - AWS health event"
      event_pattern = {
        source      = ["aws.health"]
        detail-type = ["AWS Health Event"]
      }
    }
    spot_interrupt = {
      name        = "SpotInterrupt"
      description = "Karpenter interrupt - EC2 spot instance interruption warning"
      event_pattern = {
        source      = ["aws.ec2"]
        detail-type = ["EC2 Spot Instance Interruption Warning"]
      }
    }
    instance_rebalance = {
      name        = "InstanceRebalance"
      description = "Karpenter interrupt - EC2 instance rebalance recommendation"
      event_pattern = {
        source      = ["aws.ec2"]
        detail-type = ["EC2 Instance Rebalance Recommendation"]
      }
    }
    instance_state_change = {
      name        = "InstanceStateChange"
      description = "Karpenter interrupt - EC2 instance state-change notification"
      event_pattern = {
        source      = ["aws.ec2"]
        detail-type = ["EC2 Instance State-change Notification"]
      }
    }
    capacity_reservation_interruption = {
      name        = "CRInterruption"
      description = "Karpenter interrupt - EC2 capacity reservation instance interruption warning"
      event_pattern = {
        source      = ["aws.ec2"]
        detail-type = ["EC2 Capacity Reservation Instance Interruption Warning"]
      }
    }
  }
}

resource "aws_sqs_queue" "this" {
  name                      = "Karpenter-${var.cluster_name}"
  message_retention_seconds = 300
  sqs_managed_sse_enabled   = true

  tags = local.common_tags
}

data "aws_iam_policy_document" "queue" {
  statement {
    sid       = "SqsWrite"
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.this.arn]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
  }

  statement {
    sid       = "DenyHTTP"
    effect    = "Deny"
    actions   = ["sqs:*"]
    resources = [aws_sqs_queue.this.arn]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }

    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }
}

resource "aws_sqs_queue_policy" "this" {
  queue_url = aws_sqs_queue.this.id
  policy    = data.aws_iam_policy_document.queue.json
}

data "aws_iam_policy_document" "karpenter_interruption" {
  statement {
    actions = [
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl",
      "sqs:ReceiveMessage",
    ]
    resources = [aws_sqs_queue.this.arn]
  }
}

resource "aws_iam_role_policy" "karpenter_interruption" {
  name   = "${var.cluster_name}-karpenter-interruption"
  role   = var.karpenter_irsa_role_name
  policy = data.aws_iam_policy_document.karpenter_interruption.json
}

resource "aws_cloudwatch_event_rule" "this" {
  for_each = local.interruption_events

  name          = substr("${var.cluster_name}-karpenter-${each.value.name}", 0, 64)
  description   = each.value.description
  event_pattern = jsonencode(each.value.event_pattern)

  tags = local.common_tags
}

resource "aws_cloudwatch_event_target" "this" {
  for_each = local.interruption_events

  rule      = aws_cloudwatch_event_rule.this[each.key].name
  target_id = "KarpenterInterruptionQueueTarget"
  arn       = aws_sqs_queue.this.arn

  depends_on = [aws_sqs_queue_policy.this]
}

resource "helm_release" "karpenter" {
  name             = "karpenter"
  namespace        = "karpenter"
  create_namespace = true
  repository       = "oci://public.ecr.aws/karpenter"
  chart            = "karpenter"
  version          = var.karpenter_version
  wait             = true

  values = [<<-EOT
    nodeSelector:
      role: system
    settings:
      clusterName: ${var.cluster_name}
      clusterEndpoint: ${var.cluster_endpoint}
      interruptionQueue: ${aws_sqs_queue.this.name}
    serviceAccount:
      annotations:
        eks.amazonaws.com/role-arn: ${var.karpenter_irsa_role_arn}
    tolerations:
      - key: CriticalAddonsOnly
        operator: Exists
        effect: NoSchedule
    webhook:
      enabled: false
  EOT
  ]

  depends_on = [
    aws_iam_role_policy.karpenter_interruption,
    aws_sqs_queue_policy.this,
  ]
}

resource "kubectl_manifest" "ec2_node_class" {
  count     = var.create_node_pool ? 1 : 0
  yaml_body = <<-YAML
    apiVersion: karpenter.k8s.aws/v1
    kind: EC2NodeClass
    metadata:
      name: default
    spec:
      kubelet:
        maxPods: 30
        systemReserved:
          cpu: 100m
          memory: 100Mi
          ephemeral-storage: 1Gi
        kubeReserved:
          cpu: 200m
          memory: 100Mi
          ephemeral-storage: 3Gi
        evictionHard:
          memory.available: 5%
          nodefs.available: 10%
          nodefs.inodesFree: 10%
        evictionSoft:
          memory.available: 500Mi
          nodefs.available: 15%
          nodefs.inodesFree: 15%
        evictionSoftGracePeriod:
          memory.available: 1m
          nodefs.available: 1m30s
          nodefs.inodesFree: 2m
        evictionMaxPodGracePeriod: 60
        imageGCHighThresholdPercent: 85
        imageGCLowThresholdPercent: 80
        cpuCFSQuota: true
      subnetSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${var.cluster_name}
      securityGroupSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${var.cluster_name}
      role: ${var.karpenter_node_role_name}
      amiSelectorTerms:
        - alias: al2023@latest
      tags:
        IntentLabel: apps
        KarpenterNodePoolName: default
        NodeType: default
        intent: apps
        karpenter.sh/discovery: ${var.cluster_name}
      metadataOptions:
        httpEndpoint: enabled
        httpProtocolIPv6: disabled
        httpPutResponseHopLimit: 1
        httpTokens: required
  YAML

  depends_on = [helm_release.karpenter]
}

resource "kubectl_manifest" "node_pool" {
  count     = var.create_node_pool ? 1 : 0
  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1
    kind: NodePool
    metadata:
      name: default
    spec:
      template:
        metadata:
          labels:
            intent: apps
        spec:
          nodeClassRef:
            group: karpenter.k8s.aws
            kind: EC2NodeClass
            name: default
          expireAfter: 720h
          terminationGracePeriod: 10m
          requirements:
            - key: "karpenter.k8s.aws/instance-category"
              operator: In
              values: ["c", "m", "r"]
            - key: "karpenter.k8s.aws/instance-family"
              operator: In
              values: ["m5","m5d","c5","c5d","c4","r4"]
            - key: karpenter.k8s.aws/instance-cpu
              operator: In
              values: ["4", "8", "16", "32"]
            - key: karpenter.k8s.aws/instance-hypervisor
              operator: In
              values: ["nitro"]
            - key: karpenter.k8s.aws/instance-generation
              operator: Gt
              values: ["2"]
            - key: kubernetes.io/arch
              operator: In
              values: ["amd64"]
            - key: karpenter.sh/capacity-type
              operator: In
              values: ${jsonencode(var.capacity_types)}
      disruption:
        consolidationPolicy: WhenEmptyOrUnderutilized
        consolidateAfter: 1m
        budgets:
          - nodes: "10%"
      limits:
        cpu: ${var.node_pool_cpu_limit}
        memory: ${var.node_pool_memory_limit}
        nodes: ${var.node_pool_node_limit}
      weight: 10

  YAML

  depends_on = [kubectl_manifest.ec2_node_class]
}
