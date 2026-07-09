output "web_acl_arn" {
  description = "WAFv2 Web ACL ARN"
  value       = aws_wafv2_web_acl.this.arn
}

output "web_acl_name" {
  description = "WAFv2 Web ACL name"
  value       = aws_wafv2_web_acl.this.name
}

output "associated_alb_arn" {
  description = "Associated ALB ARN"
  value       = try(data.aws_lb.this[0].arn, null)
}
