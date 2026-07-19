output "node_pool_name" {
  value = var.create_node_pool ? "default" : null
}

output "interruption_queue_name" {
  value = aws_sqs_queue.this.name
}

output "interruption_queue_arn" {
  value = aws_sqs_queue.this.arn
}
