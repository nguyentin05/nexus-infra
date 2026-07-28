variable "cluster_name" {
  description = "EKS cluster name used for Kubernetes subnet discovery tags"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
}

variable "public_subnets" {
  description = "Map of availability zone to public subnet CIDR"
  type        = map(string)

  validation {
    condition     = length(var.public_subnets) > 0
    error_message = "At least one public subnet is required."
  }
}

variable "private_subnets" {
  description = "Map of availability zone to private subnet CIDR"
  type        = map(string)

  validation {
    condition     = length(var.private_subnets) > 0
    error_message = "At least one private subnet is required."
  }

  validation {
    condition     = sort(keys(var.private_subnets)) == sort(keys(var.public_subnets))
    error_message = "Public and private subnets must use the same availability zones."
  }
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
