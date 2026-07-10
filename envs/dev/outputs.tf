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
  value       = module.acm.certificate_arn
}

output "cloudflare_zone_id" {
  description = "Cloudflare DNS zone ID"
  value       = module.acm.cloudflare_zone_id
}
