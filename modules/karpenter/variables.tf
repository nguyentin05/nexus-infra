variable "environment" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "cluster_endpoint" {
  type = string
}

variable "karpenter_irsa_role_arn" {
  type = string
}

variable "karpenter_node_role_name" {
  description = "The name of the IAM role for Karpenter nodes (used by EC2NodeClass)"
  type        = string
}

variable "karpenter_version" {
  type    = string
  default = "1.1.1"
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "node_security_group_id" {
  type = string
}

variable "instance_families" {
  type    = list(string)
  default = ["m5", "m6i", "c5"]
}

variable "instance_sizes" {
  type    = list(string)
  default = ["large", "xlarge"]
}