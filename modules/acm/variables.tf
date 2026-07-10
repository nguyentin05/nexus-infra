variable "environment" {
  description = "Environment name"
  type        = string
}

variable "domain_name" {
  description = "Primary certificate domain name"
  type        = string
}

variable "subject_alternative_names" {
  description = "Additional certificate domain names"
  type        = list(string)
  default     = []
}

variable "cloudflare_zone_name" {
  description = "Cloudflare DNS zone name used for ACM validation records"
  type        = string
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
