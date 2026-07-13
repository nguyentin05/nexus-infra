variable "enabled" {
  description = "Whether to create and associate the Web ACL"
  type        = bool
  default     = true
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "name" {
  description = "Web ACL name"
  type        = string
}

variable "alb_arn" {
  description = "Optional ALB ARN to associate with the Web ACL"
  type        = string
  default     = null
  nullable    = true
}

variable "associate_alb" {
  description = "Whether to associate this Web ACL with the provided ALB ARN"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}

variable "override_size_restrictions_body_to_count" {
  description = "Whether to count, instead of block, AWS CommonRuleSet SizeRestrictions_BODY matches"
  type        = bool
  default     = false
}

variable "override_cross_site_scripting_body_to_count" {
  description = "Whether to count, instead of block, AWS CommonRuleSet CrossSiteScripting_BODY matches"
  type        = bool
  default     = false
}
