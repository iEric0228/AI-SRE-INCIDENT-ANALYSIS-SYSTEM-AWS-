variable "table_name" {
  description = "Name of the DynamoDB table for incident storage"
  type        = string
  default     = "incident-analysis-store"
}

variable "kms_key_arn" {
  description = "ARN of the KMS key for encryption at rest"
  type        = string
}

variable "tags" {
  description = "Additional tags to apply to the DynamoDB table"
  type        = map(string)
  default     = {}
}
