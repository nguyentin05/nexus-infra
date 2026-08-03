output "user_events_queue_url" {
  description = "URL of the SQS queue used for user lifecycle events"
  value       = module.sqs.queue_url
}

output "user_events_queue_arn" {
  description = "ARN of the SQS queue used for user lifecycle events"
  value       = module.sqs.queue_arn
}

output "database_endpoint" {
  description = "RDS PostgreSQL connection endpoint"
  value       = module.rds.endpoint
}

output "database_master_user_secret_arn" {
  description = "AWS-managed RDS master user secret ARN"
  value       = module.rds.master_user_secret_arn
}

output "app_irsa_role_arns" {
  description = "Application IRSA role ARNs"
  value       = module.iam.app_irsa_role_arns
}

output "acm_certificate_arn" {
  description = "Validated ACM certificate ARN for CloudFront"
  value       = data.aws_acm_certificate.api.arn
}

output "cloudflare_zone_id" {
  description = "Cloudflare DNS zone ID"
  value       = data.cloudflare_zone.this.id
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = module.cloudfront.distribution_id
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  value       = module.cloudfront.domain_name
}

output "cloudfront_hosted_zone_id" {
  description = "CloudFront hosted zone ID"
  value       = module.cloudfront.hosted_zone_id
}


output "public_alb_dns_name" {
  description = "Public API ALB DNS name"
  value       = module.alb.dns_name
}

output "public_alb_arn" {
  description = "Public API ALB ARN"
  value       = module.alb.load_balancer_arn
}

output "envoy_target_group_name" {
  description = "Stable Target Group name used by TargetGroupBinding"
  value       = module.alb.target_group_name
}

output "envoy_target_group_arn" {
  description = "Envoy Gateway target group ARN"
  value       = module.alb.target_group_arn
}

output "api_domain_name" {
  description = "Public API domain name"
  value       = cloudflare_dns_record.api.name
}
