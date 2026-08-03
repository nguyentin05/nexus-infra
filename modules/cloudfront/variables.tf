variable "name" {
  description = "CloudFront distribution name"
  type        = string
}

variable "origin_domain_name" {
  description = "Origin domain name used by CloudFront"
  type        = string
}

variable "aliases" {
  description = "Custom domain aliases for the distribution"
  type        = list(string)
}

variable "certificate_arn" {
  description = "ACM certificate ARN in us-east-1"
  type        = string
}

variable "origin_protocol_policy" {
  description = "Protocol policy used by CloudFront when connecting to the ALB origin"
  type        = string
  default     = "http-only"
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
