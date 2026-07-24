variable "environment" {
  type = string
}

variable "cluster_version" {
  type    = string
  default = "1.36"
}

variable "private_subnet_ids" {
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


variable "system_node_max_pods" {
  description = "Optional kubelet maxPods override for the system managed node group. Set with VPC CNI prefix delegation."
  type        = number
  default     = null
}

variable "enable_vpc_cni_prefix_delegation" {
  description = "Enable Amazon VPC CNI prefix delegation to increase pod IP capacity per node."
  type        = bool
  default     = false
}

variable "vpc_cni_warm_prefix_target" {
  description = "Number of extra /28 prefixes the VPC CNI keeps warm when prefix delegation is enabled."
  type        = number
  default     = 1
}
