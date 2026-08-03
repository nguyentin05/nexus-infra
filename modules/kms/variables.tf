variable "environment" {
  description = "Optional deployment environment used to namespace the KMS alias"
  type        = string
  default     = null
}

variable "key_alias" {
  description = "KMS key alias without the alias/ or environment prefix"
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