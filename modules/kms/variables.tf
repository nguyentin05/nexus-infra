variable "environment" {
  type = string
}

variable "key_alias" {
  description = "Alias cho KMS key, VD: vault-unseal"
  type        = string
}

variable "deletion_window_in_days" {
  type    = number
  default = 7
}

variable "tags" {
  type    = map(string)
  default = {}
}