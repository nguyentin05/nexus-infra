variable "identifier" {
  description = "RDS instance identifier"
  type        = string
}

variable "database_name" {
  description = "Initial database name"
  type        = string
}

variable "master_username" {
  description = "Master database username"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs for the DB subnet group"
  type        = list(string)
}

variable "allowed_security_group_id" {
  description = "Security group ID allowed to connect to PostgreSQL"
  type        = string
}

variable "instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "engine_version" {
  description = "PostgreSQL major version for the RDS instance"
  type        = string
  default     = "18"
}

variable "parameter_group_family" {
  description = "RDS PostgreSQL parameter group family matching engine_version"
  type        = string
  default     = "postgres18"
}

variable "allocated_storage" {
  description = "Allocated storage in GiB"
  type        = number
  default     = 20
}

variable "backup_retention_period" {
  description = "Backup retention period in days"
  type        = number
  default     = 1
}

variable "log_retention_days" {
  description = "CloudWatch retention for exported PostgreSQL logs"
  type        = number
  default     = 7
}

variable "multi_az" {
  description = "Whether to enable Multi-AZ deployment"
  type        = bool
  default     = false
}

variable "deletion_protection" {
  description = "Whether to enable deletion protection"
  type        = bool
  default     = false
}

variable "skip_final_snapshot" {
  description = "Whether to skip the final snapshot on deletion"
  type        = bool
  default     = true
}

variable "apply_immediately" {
  description = "Whether database modifications are applied immediately instead of during the next maintenance window"
  type        = bool
  default     = false
}

variable "performance_insights_kms_key_id" {
  description = "Customer-managed KMS key ARN used to encrypt Performance Insights data"
  type        = string
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
