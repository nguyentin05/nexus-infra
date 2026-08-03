variable "environment" {
  type = string
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

variable "user_events_queue_arn" {
  description = "ARN of the SQS queue used for user lifecycle events"
  type        = string
}
