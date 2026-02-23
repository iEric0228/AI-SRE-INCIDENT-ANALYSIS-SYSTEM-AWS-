# EventBridge and SNS Module Variables

variable "project_name" {
  description = "Name of the project, used for resource naming"
  type        = string
}

variable "event_transformer_lambda_arn" {
  description = "ARN of the Lambda function that transforms CloudWatch Alarm events"
  type        = string
}

variable "kms_key_id" {
  description = "KMS key ID for encrypting SNS topic and SQS queue"
  type        = string
}

variable "alarm_notification_topic_arn" {
  description = "ARN of SNS topic for CloudWatch alarm notifications (for DLQ monitoring)"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
