variable "state_bucket_name" {
  description = "Globally unique S3 bucket name used for Terraform state"
  type        = string
  default     = "terraform-state-065320271480-ap-southeast-1-an"
}

variable "aws_region" {
  description = "AWS region for the state bucket"
  type        = string
  default     = "ap-southeast-1"
}
