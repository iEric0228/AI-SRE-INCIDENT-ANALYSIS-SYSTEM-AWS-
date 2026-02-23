# Lambda Functions Module

This Terraform module creates all 6 Lambda functions for the AI-Assisted SRE Incident Analysis System with appropriate configurations for ARM64 architecture, memory, timeouts, and environment variables.

## Features

- **ARM64 Architecture**: All functions use Graviton2 processors for cost efficiency
- **Optimized Memory Settings**: Each function has memory configured based on workload
- **Appropriate Timeouts**: Timeouts set according to expected execution time
- **CloudWatch Logs**: 7-day retention for all function logs
- **Environment Variables**: Pre-configured with necessary AWS resource references
- **IAM Integration**: Uses roles from the IAM module with least-privilege permissions

## Lambda Functions

| Function | Memory | Timeout | Purpose |
|----------|--------|---------|---------|
| metrics_collector | 512 MB | 20s | Query CloudWatch Metrics API |
| logs_collector | 512 MB | 20s | Query CloudWatch Logs API |
| deploy_context_collector | 512 MB | 20s | Query CloudTrail and SSM Parameter Store |
| correlation_engine | 256 MB | 10s | Merge and normalize collector outputs |
| llm_analyzer | 1024 MB | 40s | Invoke Amazon Bedrock for analysis |
| notification_service | 256 MB | 15s | Send Slack and email notifications |

## Usage

```hcl
module "lambda" {
  source = "./modules/lambda"

  project_name        = "ai-sre-incident-analysis"
  aws_region          = "us-east-1"
  dynamodb_table_name = module.dynamodb.table_name
  sns_topic_arn       = module.sns.topic_arn
  log_level           = "INFO"

  iam_role_arns = module.iam.lambda_role_arns

  lambda_packages = {
    metrics_collector        = "${path.module}/packages/metrics_collector.zip"
    logs_collector           = "${path.module}/packages/logs_collector.zip"
    deploy_context_collector = "${path.module}/packages/deploy_context_collector.zip"
    correlation_engine       = "${path.module}/packages/correlation_engine.zip"
    llm_analyzer             = "${path.module}/packages/llm_analyzer.zip"
    notification_service     = "${path.module}/packages/notification_service.zip"
  }

  tags = {
    Project     = "AI-SRE-Portfolio"
    Environment = "dev"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| project_name | Project name used for resource naming | string | "ai-sre-incident-analysis" | no |
| aws_region | AWS region where resources are deployed | string | - | yes |
| iam_role_arns | Map of IAM role ARNs for Lambda functions | object | - | yes |
| lambda_packages | Map of Lambda deployment package file paths | object | - | yes |
| dynamodb_table_name | Name of the DynamoDB incident store table | string | - | yes |
| sns_topic_arn | ARN of the SNS topic for incident notifications | string | - | yes |
| log_level | Log level for Lambda functions | string | "INFO" | no |
| tags | Tags to apply to all Lambda resources | map(string) | {"Project": "AI-SRE-Portfolio"} | no |

## Outputs

| Name | Description |
|------|-------------|
| lambda_function_arns | Map of all Lambda function ARNs |
| lambda_function_names | Map of all Lambda function names |
| log_group_arns | Map of CloudWatch Log Group ARNs |
| metrics_collector_arn | ARN of the Metrics Collector Lambda function |
| logs_collector_arn | ARN of the Logs Collector Lambda function |
| deploy_context_collector_arn | ARN of the Deploy Context Collector Lambda function |
| correlation_engine_arn | ARN of the Correlation Engine Lambda function |
| llm_analyzer_arn | ARN of the LLM Analyzer Lambda function |
| notification_service_arn | ARN of the Notification Service Lambda function |

## Environment Variables

Each Lambda function receives the following environment variables:

### Common Variables (All Functions)
- `AWS_REGION`: AWS region for API calls
- `DYNAMODB_TABLE`: Name of the incident store table
- `LOG_LEVEL`: Logging level (DEBUG, INFO, WARNING, ERROR)
- `INCIDENT_TOPIC_ARN`: SNS topic ARN for incident notifications

### Function-Specific Variables

#### Correlation Engine
- `MAX_CONTEXT_SIZE`: Maximum context size in bytes (50KB)

#### LLM Analyzer
- `BEDROCK_MODEL_ID`: Bedrock model identifier (anthropic.claude-v2)
- `PROMPT_TEMPLATE_PARAM`: SSM Parameter Store path for prompt template

#### Notification Service
- `SLACK_SECRET_NAME`: Secrets Manager secret name for Slack webhook
- `EMAIL_TOPIC_ARN`: SNS topic ARN for email notifications
- `INCIDENT_STORE_URL`: URL to DynamoDB console for incident details

## CloudWatch Logs

All Lambda functions have CloudWatch Log Groups with:
- **Retention**: 7 days
- **Log Format**: Structured JSON with correlation IDs
- **Naming**: `/aws/lambda/{function-name}`

## Cost Optimization

This module implements several cost optimization strategies:

1. **ARM64 Architecture**: ~20% cost reduction vs x86_64
2. **Right-Sized Memory**: Each function has memory optimized for workload
3. **Short Log Retention**: 7 days reduces CloudWatch Logs costs
4. **Efficient Timeouts**: Prevents long-running executions

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| aws | >= 4.0 |

## Dependencies

This module depends on:
- **IAM Module**: Provides IAM role ARNs
- **DynamoDB Module**: Provides table name
- **SNS Module**: Provides topic ARN

## Notes

- Lambda deployment packages must be created separately (see `src/` directory)
- Functions use Python 3.11 runtime
- All functions support X-Ray tracing (configured in orchestrator)
- Source code hash triggers automatic updates on code changes
