variable "environment" {
  type = string
}

variable "cluster_version" {
  type    = string
  default = "1.36"
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "system_node_instance_type" {
  type    = string
  default = "t3.small"
}

variable "system_node_desired_size" {
  type    = number
  default = 2
}

variable "public_access_cidrs" {
  description = "CIDR ranges allowed to access the EKS public endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "tags" {
  type    = map(string)
  default = {}
}
variable "cluster_admin_principal_arn" {
  description = "IAM principal ARN granted cluster administrator access"
  type        = string
  default     = null
}
