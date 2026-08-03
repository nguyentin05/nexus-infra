variable "environment" {
  description = "Environment name"
  type        = string
}

variable "name" {
  description = "NLB name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the NLB and target group are created"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for the internet-facing NLB"
  type        = list(string)
}

variable "target_security_group_id" {
  description = "Security group attached to the Kubernetes nodes or pod ENIs"
  type        = string
}

variable "target_group_name" {
  description = "Stable target group name referenced by Kubernetes TargetGroupBinding"
  type        = string
}

variable "target_port" {
  description = "Envoy proxy target port registered by TargetGroupBinding"
  type        = number
  default     = 10080
}

variable "health_check_path" {
  description = "NLB target group HTTP health check path"
  type        = string
  default     = "/auth"
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
