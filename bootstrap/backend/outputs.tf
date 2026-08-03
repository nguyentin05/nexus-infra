output "state_bucket_name" {
  description = "S3 bucket used by Terraform backends"
  value       = aws_s3_bucket.tfstate.id
}
