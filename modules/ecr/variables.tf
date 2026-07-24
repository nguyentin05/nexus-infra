variable "environment" {
  description = "Environment name"
  type        = string
}

variable "repository_names" {
  description = "ECR repository names managed by this module"
  type        = set(string)
}

variable "force_delete" {
  description = "Delete repositories even when they contain images"
  type        = bool
  default     = false
}

variable "kms_key_arn" {
  description = "Customer-managed KMS key ARN used to encrypt repositories"
  type        = string
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
