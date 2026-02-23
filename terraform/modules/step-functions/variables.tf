# Variables for Step Functions module

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "ai-sre-incident-analysis"
}

variable "state_machine_role_arn" {
  description = "ARN of the IAM role for Step Functions state machine"
  type        = string
}

variable "lambda_function_arns" {
  description = "Map of Lambda function ARNs for state machine tasks"
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

variable "tags" {
  description = "Tags to apply to all Step Functions resources"
  type        = map(string)
  default = {
    Project = "AI-SRE-Portfolio"
  }
}

