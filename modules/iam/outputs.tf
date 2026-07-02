output "irsa_role_arns" {
  description = "Map role_name => ARN cho lb_controller, karpenter, external_dns, vault"
  value       = { for k, v in aws_iam_role.irsa : k => v.arn }
}

output "ebs_csi_role_arn" {
  value = aws_iam_role.ebs_csi.arn
}

output "karpenter_node_role_name" {
  description = "The name of the Karpenter node IAM role"
  value       = aws_iam_role.karpenter_node.name
}