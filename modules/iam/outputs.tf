output "irsa_role_arns" {
  description = "Map of IRSA role names to ARNs for controllers and application services"
  value = {
    lb_controller   = aws_iam_role.lb_controller.arn
    vault           = aws_iam_role.vault.arn
    kyverno         = aws_iam_role.kyverno.arn
    grafana         = aws_iam_role.grafana.arn
    auth_service    = aws_iam_role.auth_service.arn
    profile_service = aws_iam_role.profile_service.arn
  }
}

output "ebs_csi_role_arn" {
  description = "ARN of the EBS CSI IRSA role"
  value       = aws_iam_role.ebs_csi.arn
}

output "lb_controller_role_arn" {
  description = "ARN of the AWS Load Balancer Controller IRSA role"
  value       = aws_iam_role.lb_controller.arn
}

output "app_irsa_role_arns" {
  description = "Map of application IRSA role names to ARNs"
  value = {
    auth_service    = aws_iam_role.auth_service.arn
    profile_service = aws_iam_role.profile_service.arn
  }
}
