locals {
  common_tags = merge(var.tags, {
    Module = "eks"
  })
}

# IAM for cluster
data "aws_iam_policy_document" "cluster_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cluster" {
  name_prefix        = "${var.environment}-eks-cluster-"
  assume_role_policy = data.aws_iam_policy_document.cluster_assume_role.json

  tags = merge(local.common_tags, {
    Name = "eks-cluster-role"
  })
}

resource "aws_iam_role_policy_attachment" "cluster_policy" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

#trivy:ignore:AVD-AWS-0039
#trivy:ignore:AVD-AWS-0040
#trivy:ignore:AVD-AWS-0041
resource "aws_eks_cluster" "this" {
  #checkov:skip=CKV_AWS_339:Kubernetes version is selected from the currently supported EKS versions.
  #checkov:skip=CKV_AWS_58:EKS 1.28 and later encrypt all Kubernetes API data by default with an AWS-owned KMS key.
  #checkov:skip=CKV_AWS_38:Endpoint CIDRs are environment inputs; development access is intentionally broad and temporary.
  #checkov:skip=CKV_AWS_39:Public access is required by the current local bootstrap and CI execution model.
  name                      = "${var.environment}-${var.name}"
  role_arn                  = aws_iam_role.cluster.arn
  version                   = var.cluster_version
  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  depends_on                = [aws_iam_role_policy_attachment.cluster_policy]

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = var.public_access_cidrs
  }

  access_config {
    authentication_mode = "API"
  }

  tags = merge(local.common_tags, {
    Name = "eks-cluster"
  })
}

resource "aws_security_group_rule" "cluster_ingress_nodes_https" {
  description              = "Worker nodes to EKS API server"
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
  source_security_group_id = var.node_security_group_id
}

resource "aws_security_group_rule" "nodes_ingress_cluster_https" {
  description              = "EKS control plane to worker nodes"
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = var.node_security_group_id
  source_security_group_id = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

resource "aws_security_group_rule" "nodes_ingress_cluster_kubelet" {
  description              = "EKS control plane to kubelet"
  type                     = "ingress"
  from_port                = 10250
  to_port                  = 10250
  protocol                 = "tcp"
  security_group_id        = var.node_security_group_id
  source_security_group_id = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

resource "aws_security_group_rule" "nodes_ingress_cluster_webhooks" {
  description              = "EKS control plane to admission webhooks"
  type                     = "ingress"
  from_port                = 9443
  to_port                  = 9443
  protocol                 = "tcp"
  security_group_id        = var.node_security_group_id
  source_security_group_id = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

data "tls_certificate" "eks" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer

  tags = merge(local.common_tags, {
    Name = "eks-oidc-provider"
  })
}

data "aws_iam_policy_document" "system_nodegroup_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "system_nodegroup" {
  name_prefix        = "${var.environment}-eks-system-node-"
  assume_role_policy = data.aws_iam_policy_document.system_nodegroup_assume_role.json

  tags = merge(local.common_tags, {
    Name = "eks-system-node-role"
  })
}

resource "aws_iam_role_policy_attachment" "system_nodegroup_worker" {
  role       = aws_iam_role.system_nodegroup.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "system_nodegroup_cni" {
  role       = aws_iam_role.system_nodegroup.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "system_nodegroup_ecr" {
  role       = aws_iam_role.system_nodegroup.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

data "aws_ssm_parameter" "eks_al2023_x86_64_ami" {
  count = var.system_node_max_pods == null ? 0 : 1
  name  = "/aws/service/eks/optimized-ami/${var.cluster_version}/amazon-linux-2023/x86_64/standard/recommended/image_id"
}

data "cloudinit_config" "system_node" {
  count = var.system_node_max_pods == null ? 0 : 1

  gzip          = false
  base64_encode = true

  part {
    content_type = "application/node.eks.aws"
    content      = <<-EOT
    ---
    apiVersion: node.eks.aws/v1alpha1
    kind: NodeConfig
    spec:
      cluster:
        name: ${aws_eks_cluster.this.name}
        apiServerEndpoint: ${aws_eks_cluster.this.endpoint}
        certificateAuthority: ${aws_eks_cluster.this.certificate_authority[0].data}
        cidr: ${aws_eks_cluster.this.kubernetes_network_config[0].service_ipv4_cidr}
      kubelet:
        config:
          maxPods: ${var.system_node_max_pods}
    EOT
  }
}

resource "aws_launch_template" "system_nodegroup" {
  count = var.system_node_max_pods == null ? 0 : 1

  name_prefix            = "${var.environment}-eks-system-node-"
  image_id               = data.aws_ssm_parameter.eks_al2023_x86_64_ami[0].value
  vpc_security_group_ids = [var.node_security_group_id]
  user_data              = data.cloudinit_config.system_node[0].rendered
  update_default_version = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tags = merge(local.common_tags, {
    Name = "eks-system-node-launch-template"
  })
}

resource "aws_eks_node_group" "system" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.environment}-system"
  node_role_arn   = aws_iam_role.system_nodegroup.arn
  subnet_ids      = var.private_subnet_ids
  instance_types  = [var.system_node_instance_type]
  capacity_type   = "ON_DEMAND"
  depends_on = [
    aws_iam_role_policy_attachment.system_nodegroup_worker,
    aws_iam_role_policy_attachment.system_nodegroup_cni,
    aws_iam_role_policy_attachment.system_nodegroup_ecr,
  ]

  dynamic "launch_template" {
    for_each = var.system_node_max_pods == null ? [] : [aws_launch_template.system_nodegroup[0]]

    content {
      id      = launch_template.value.id
      version = launch_template.value.latest_version
    }
  }

  scaling_config {
    desired_size = var.system_node_desired_size
    max_size     = var.system_node_desired_size
    min_size     = var.system_node_desired_size
  }

  labels = {
    role = "system"
  }

  taint {
    key    = "CriticalAddonsOnly"
    value  = "true"
    effect = "NO_SCHEDULE"
  }

  tags = merge(local.common_tags, {
    Name = "eks-system-node-group"
  })
}

resource "aws_eks_addon" "vpc_cni" {
  cluster_name = aws_eks_cluster.this.name
  addon_name   = "vpc-cni"

  configuration_values = var.enable_vpc_cni_prefix_delegation ? jsonencode({
    env = {
      ENABLE_PREFIX_DELEGATION = "true"
      WARM_PREFIX_TARGET       = tostring(var.vpc_cni_warm_prefix_target)
    }
  }) : null

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [aws_eks_node_group.system]

  tags = merge(local.common_tags, {
    Name = "eks-vpc-cni-addon"
  })
}

resource "aws_eks_addon" "coredns" {
  cluster_name = aws_eks_cluster.this.name
  addon_name   = "coredns"
  depends_on   = [aws_eks_node_group.system]

  tags = merge(local.common_tags, {
    Name = "eks-coredns-addon"
  })
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name = aws_eks_cluster.this.name
  addon_name   = "kube-proxy"
  depends_on   = [aws_eks_node_group.system]

  tags = merge(local.common_tags, {
    Name = "eks-kube-proxy-addon"
  })
}

resource "aws_eks_access_entry" "admin" {
  count         = var.cluster_admin_principal_arn == null ? 0 : 1
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = var.cluster_admin_principal_arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "admin" {
  count         = var.cluster_admin_principal_arn == null ? 0 : 1
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = var.cluster_admin_principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  depends_on    = [aws_eks_access_entry.admin]

  access_scope {
    type = "cluster"
  }
}
