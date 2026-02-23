# Variables for Lambda module

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "ai-sre-incident-analysis"
}

variable "aws_region" {
  description = "AWS region where resources are deployed"
  type        = string
}

variable "iam_role_arns" {
  description = "Map of IAM role ARNs for Lambda functions"
  type = object({
    metrics_collector        = string
    logs_collector           = string
    deploy_context_collector = string
    correlation_engine       = string
    llm_analyzer             = string
    notification_service     = string
  })
}

variable "lambda_packages" {
  description = "Map of Lambda deployment package file paths"
  type = object({
    metrics_collector        = string
    logs_collector           = string
    deploy_context_collector = string
    correlation_engine       = string
    llm_analyzer             = string
    notification_service     = string
  })
}

variable "dynamodb_table_name" {
  description = "Name of the DynamoDB incident store table"
  type        = string
}

variable "sns_topic_arn" {
  description = "ARN of the SNS topic for incident notifications"
  type        = string
}

variable "log_level" {
  description = "Log level for Lambda functions (DEBUG, INFO, WARNING, ERROR)"
  type        = string
  default     = "INFO"
}

variable "tags" {
  description = "Tags to apply to all Lambda resources"
  type        = map(string)
  default = {
    Project = "AI-SRE-Portfolio"
  }
}
