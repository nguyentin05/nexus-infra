variable "environment" {
  description = "Environment name"
  type        = string
}

variable "queue_name" {
  description = "SQS queue name"
  type        = string
}

variable "visibility_timeout_seconds" {
  description = "Queue visibility timeout in seconds"
  type        = number
  default     = 30
}

variable "message_retention_seconds" {
  description = "Queue message retention period in seconds"
  type        = number
  default     = 345600
}

variable "max_receive_count" {
  description = "Number of receives before moving a message to the dead-letter queue"
  type        = number
  default     = 5
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
