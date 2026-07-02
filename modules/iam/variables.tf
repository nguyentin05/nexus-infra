variable "environment" {
  type = string
}

variable "cluster_name" {
  description = "The name of the EKS cluster"
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN của OIDC provider, lấy từ module eks"
  type        = string
}

variable "oidc_provider_url" {
  description = "URL OIDC provider (không có https://), lấy từ module eks"
  type        = string
}

variable "vault_kms_key_arn" {
  description = "ARN KMS key dùng cho Vault auto-unseal"
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}