output "load_balancer_arn" {
  description = "NLB ARN"
  value       = aws_lb.this.arn
}

output "dns_name" {
  description = "NLB DNS name"
  value       = aws_lb.this.dns_name
}

output "zone_id" {
  description = "NLB canonical hosted zone ID"
  value       = aws_lb.this.zone_id
}

output "security_group_id" {
  description = "NLB security group ID"
  value       = aws_security_group.this.id
}

output "target_group_arn" {
  description = "Envoy Gateway target group ARN"
  value       = aws_lb_target_group.envoy.arn
}

output "target_group_name" {
  description = "Envoy Gateway target group name"
  value       = aws_lb_target_group.envoy.name
}

output "listener_arn" {
  description = "TCP listener ARN"
  value       = aws_lb_listener.http.arn
}
