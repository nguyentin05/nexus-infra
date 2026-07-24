output "repository_urls" {
  description = "Map of ECR repository names to URLs"
  value       = { for name, repository in aws_ecr_repository.this : name => repository.repository_url }
}
