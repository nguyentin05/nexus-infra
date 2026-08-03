output "node_pool_name" {
  value = var.create_node_pool ? "default" : null
}

output "interruption_queue_name" {
  value = module.aws_resources.queue_name
}

output "interruption_queue_arn" {
  value = module.aws_resources.queue_arn
}
