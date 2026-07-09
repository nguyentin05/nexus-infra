variable "environment" {
  description = "Environment name"
  type        = string
}

variable "name" {
  description = "Web ACL name"
  type        = string
}

variable "alb_name" {
  description = "ALB name to associate with the Web ACL"
  type        = string
  default     = null
  nullable    = true
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
