output "acm_certificate_arn" {
  description = "Validated wildcard ACM certificate ARN in us-east-1"
  value       = module.acm.certificate_arn
}

output "cloudflare_zone_id" {
  description = "Cloudflare DNS zone ID"
  value       = module.acm.cloudflare_zone_id
}

output "ecr_repository_urls" {
  description = "Shared application ECR repository URLs"
  value       = module.ecr.repository_urls
}

output "github_actions_app_role_arn" {
  description = "IAM role ARN used by nexus-app to publish signed ECR images"
  value       = aws_iam_role.app_release.arn
}
