variable "project_name" {
  description = "Name of the project (used for resource naming)"
  type        = string
  default     = "incident-analysis"
}

variable "slack_webhook_url" {
  description = "Slack webhook URL (placeholder - should be updated after deployment)"
  type        = string
  default     = "https://hooks.slack.com/services/PLACEHOLDER"
  sensitive   = true
}

variable "email_sns_topic_arn" {
  description = "ARN of the SNS topic for email notifications"
  type        = string
  default     = ""
}

variable "email_from_address" {
  description = "Email address to send notifications from"
  type        = string
  default     = "incidents@example.com"
}

variable "email_recipients" {
  description = "List of email addresses to receive incident notifications"
  type        = list(string)
  default     = ["oncall@example.com"]
}

variable "enable_rotation" {
  description = "Enable automatic secret rotation"
  type        = bool
  default     = false
}

variable "rotation_days" {
  description = "Number of days between automatic secret rotations"
  type        = number
  default     = 90
}

variable "rotation_lambda_arn" {
  description = "ARN of the Lambda function for secret rotation (required if enable_rotation is true)"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Additional tags to apply to secrets"
  type        = map(string)
  default     = {}
}
