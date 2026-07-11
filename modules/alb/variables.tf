variable "environment" {
  description = "Environment name"
  type        = string
}

variable "name" {
  description = "ALB name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the ALB and target group are created"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for the internet-facing ALB"
  type        = list(string)
}

variable "target_security_group_id" {
  description = "Security group attached to the Kubernetes nodes/pod ENIs that receive ALB traffic"
  type        = string
}

variable "target_group_name" {
  description = "Stable Target Group name referenced by Kubernetes TargetGroupBinding"
  type        = string
}

variable "target_port" {
  description = "Envoy proxy target port registered by TargetGroupBinding"
  type        = number
  default     = 10080
}

variable "health_check_path" {
  description = "ALB target group health check path"
  type        = string
  default     = "/auth"
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
