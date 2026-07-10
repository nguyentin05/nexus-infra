output "certificate_arn" {
  description = "Validated ACM certificate ARN"
  value       = aws_acm_certificate_validation.this.certificate_arn
}

output "certificate_domain_name" {
  description = "Primary certificate domain name"
  value       = aws_acm_certificate.this.domain_name
}

output "cloudflare_zone_id" {
  description = "Cloudflare DNS zone ID"
  value       = local.cloudflare_zone_id
}
