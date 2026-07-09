output "irsa_role_arns" {
  description = "Map of IRSA role names to ARNs for AWS Load Balancer Controller, Karpenter, ExternalDNS, and Vault"
  value = {
    lb_controller = aws_iam_role.lb_controller.arn
    karpenter     = aws_iam_role.karpenter.arn
    external_dns  = aws_iam_role.external_dns.arn
    vault         = aws_iam_role.vault.arn
  }
}

output "ebs_csi_role_arn" {
  description = "ARN of the EBS CSI driver IRSA role"
  value       = aws_iam_role.ebs_csi.arn
}

output "karpenter_node_role_name" {
  description = "The name of the Karpenter node IAM role"
  value       = aws_iam_role.karpenter_node.name
}


output "lb_controller_role_arn" {
  description = "ARN of the AWS Load Balancer Controller IRSA role"
  value       = aws_iam_role.lb_controller.arn
}
