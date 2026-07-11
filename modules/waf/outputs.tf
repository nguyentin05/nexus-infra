output "web_acl_arn" {
  description = "WAFv2 Web ACL ARN"
  value       = try(aws_wafv2_web_acl.this[0].arn, null)
}

output "web_acl_name" {
  description = "WAFv2 Web ACL name"
  value       = try(aws_wafv2_web_acl.this[0].name, null)
}

output "associated_alb_arn" {
  description = "Associated ALB ARN"
  value       = try(aws_wafv2_web_acl_association.alb[0].resource_arn, null)
}
