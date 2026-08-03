variable "cluster_name" {
  type = string
}

variable "cluster_endpoint" {
  type = string
}

variable "oidc_provider_arn" {
  description = "ARN of the EKS OIDC provider used by the Karpenter controller IRSA role"
  type        = string
}

variable "karpenter_version" {
  type    = string
  default = "1.13.0"
}

variable "capacity_types" {
  description = "EC2 capacity types Karpenter may provision. Spot requires interruption handling before use."
  type        = list(string)
  default     = ["on-demand"]
}

variable "instance_types" {
  description = "Exact EC2 instance types Karpenter may provision"
  type        = list(string)

  validation {
    condition     = length(var.instance_types) > 0
    error_message = "instance_types must contain at least one EC2 instance type."
  }
}

variable "node_pool_cpu_limit" {
  description = "Maximum aggregate vCPU capacity Karpenter may provision through the default NodePool."
  type        = number
  default     = 16
}

variable "node_pool_memory_limit" {
  description = "Maximum aggregate memory Karpenter may provision through the default NodePool."
  type        = string
  default     = "64Gi"
}

variable "node_pool_node_limit" {
  description = "Maximum number of nodes Karpenter may provision through the default NodePool."
  type        = number
  default     = 10
}

variable "create_node_pool" {
  description = "Create the default Karpenter NodePool and EC2NodeClass after Karpenter CRDs are available"
  type        = bool
  default     = false
}

variable "tags" {
  type    = map(string)
  default = {}
}
