output "provider_arn" {
  description = "GitHub Actions OIDC provider ARN"
  value       = aws_iam_openid_connect_provider.github_actions.arn
}

output "terraform_ci_role_arn" {
  description = "IAM role used by nexus-infra GitHub Actions"
  value       = aws_iam_role.terraform_ci.arn
}

output "terraform_plan_role_arn" {
  description = "Read-only IAM role used to plan pull requests"
  value       = aws_iam_role.terraform_plan.arn
}
