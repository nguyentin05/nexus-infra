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

variable "override_hosting_provider_ip_list_to_count" {
  description = "Whether to count, instead of block, AWS AnonymousIpList HostingProviderIPList matches"
  type        = bool
  default     = false
}
