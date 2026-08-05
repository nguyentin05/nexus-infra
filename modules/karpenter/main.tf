locals {
  common_tags = merge(var.tags, {
    Module = "karpenter"
  })
}

module "aws_resources" {
  #checkov:skip=CKV_TF_1:The Terraform Registry module is pinned to an exact version.
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "21.24.1"

  cluster_name = var.cluster_name

  enable_pod_identity             = false
  enable_irsa                     = true
  irsa_oidc_provider_arn          = var.oidc_provider_arn
  irsa_namespace_service_accounts = ["karpenter:karpenter"]
  enable_v1_permissions           = true

  iam_role_name           = "${var.cluster_name}-karpenter-controller"
  node_iam_role_name      = "${var.cluster_name}-karpenter-node"
  enable_spot_termination = true
  queue_name              = "Karpenter-${var.cluster_name}"
  create_access_entry     = true
  create_node_iam_role    = true

  node_iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  tags = local.common_tags
}

resource "helm_release" "karpenter" {
  name             = "karpenter"
  namespace        = "karpenter"
  create_namespace = true
  repository       = "oci://public.ecr.aws/karpenter"
  chart            = "karpenter"
  version          = var.karpenter_version
  wait             = true
  timeout          = 600

  values = [<<-EOT
    nodeSelector:
      role: system
    settings:
      clusterName: ${var.cluster_name}
      clusterEndpoint: ${var.cluster_endpoint}
      interruptionQueue: ${module.aws_resources.queue_name}
    serviceAccount:
      annotations:
        eks.amazonaws.com/role-arn: ${module.aws_resources.iam_role_arn}
    tolerations:
      - key: CriticalAddonsOnly
        operator: Exists
        effect: NoSchedule
    webhook:
      enabled: false
  EOT
  ]

  depends_on = [module.aws_resources]
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
            karpenter.sh/node-security-group: ${var.cluster_name}
      role: ${module.aws_resources.node_iam_role_name}
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
            - key: node.kubernetes.io/instance-type
              operator: In
              values: ${jsonencode(var.instance_types)}
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
