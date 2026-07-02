variable "environment" {
  type = string
}

variable "cluster_name" {
  description = "The name of the EKS cluster"
  type        = string
}

variable "oidc_provider_arn" {
  description = "OIDC provider ARN from the EKS module"
  type        = string
}

variable "oidc_provider_url" {
  description = "OIDC provider URL without the https scheme"
  type        = string
}

variable "vault_kms_key_arn" {
  description = "KMS key ARN used for Vault auto-unseal"
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}