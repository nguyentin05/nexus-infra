resource "kubernetes_manifest" "ec2_node_class" {
  manifest = {
    apiVersion = "karpenter.k8s.aws/v1"
    kind       = "EC2NodeClass"
    metadata = {
      name = "${var.environment}-default"
    }
    spec = {
      amiFamily = "AL2023"
      role      = var.karpenter_node_role_name
      subnetSelectorTerms = [
        for id in var.private_subnet_ids : { id = id }
      ]
      securityGroupSelectorTerms = [
        { id = var.node_security_group_id }
      ]
      tags = {
        Environment = var.environment
        ManagedBy   = "karpenter"
      }
    }
  }

  depends_on = [helm_release.karpenter]
}

resource "kubernetes_manifest" "node_pool" {
  manifest = {
    apiVersion = "karpenter.sh/v1"
    kind       = "NodePool"
    metadata = {
      name = "${var.environment}-default"
    }
    spec = {
      template = {
        spec = {
          requirements = [
            {
              key      = "karpenter.k8s.aws/instance-family"
              operator = "In"
              values   = var.instance_families
            },
            {
              key      = "karpenter.k8s.aws/instance-size"
              operator = "In"
              values   = var.instance_sizes
            },
            {
              key      = "karpenter.sh/capacity-type"
              operator = "In"
              values   = ["spot"]
            }
          ]
          nodeClassRef = {
            group = "karpenter.k8s.aws"
            kind  = "EC2NodeClass"
            name  = "${var.environment}-default"
          }
        }
      }
      limits = {
        cpu = "100"
      }
      disruption = {
        consolidationPolicy = "WhenEmptyOrUnderutilized"
        consolidateAfter    = "30s"
      }
    }
  }

  depends_on = [kubernetes_manifest.ec2_node_class]
}