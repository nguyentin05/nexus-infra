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
  default = "t3.medium"
}

variable "system_node_desired_size" {
  type    = number
  default = 2
}

variable "public_access_cidrs" {
  description = "CIDR được phép truy cập public endpoint. Dev để 0.0.0.0/0, prod giới hạn IP cụ thể"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "tags" {
  type    = map(string)
  default = {}
}