variable "cluster_name" {
  type = string
}

variable "cluster_endpoint" {
  type = string
}

variable "karpenter_irsa_role_arn" {
  type = string
}

variable "karpenter_irsa_role_name" {
  type = string
}

variable "karpenter_node_role_name" {
  description = "The name of the IAM role for Karpenter nodes (used by EC2NodeClass)"
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
