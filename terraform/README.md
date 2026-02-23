# Terraform Infrastructure

This directory contains the Infrastructure as Code (IaC) for the AI-Assisted SRE Incident Analysis System.

## Overview

The infrastructure is organized into reusable Terraform modules that deploy a complete event-driven incident analysis pipeline on AWS.

## Directory Structure

```
terraform/
├── main.tf                    # Root module (to be created)
├── variables.tf               # Input variables with validation
├── outputs.tf                 # Output values for integration
├── terraform.tfvars.example   # Example variable values (to be created)
├── modules/                   # Reusable infrastructure modules
│   ├── lambda/                # Lambda functions
│   ├── step-functions/        # Step Functions orchestrator
│   ├── dynamodb/              # DynamoDB incident store
│   ├── eventbridge/           # EventBridge rules and SNS
│   ├── iam/                   # IAM roles and policies
│   ├── secrets/               # Secrets Manager configuration
│   └── cloudwatch-alarms/     # CloudWatch alarms
└── test-scenario/             # Test infrastructure for demos
```

## Prerequisites

- Terraform >= 1.0
- AWS CLI configured with appropriate credentials
- AWS account with permissions to create resources

## Variables

### Required Variables

- `environment` - Environment name (dev, staging, prod)

### Important Optional Variables

- `aws_region` - AWS region (default: us-east-1)
- `project_name` - Project name prefix (default: ai-sre-incident-analysis)
- `email_notification_endpoints` - List of email addresses for notifications
- `slack_webhook_secret_name` - Secrets Manager secret name for Slack webhook

### Alarm Thresholds

- `cpu_threshold` - CPU utilization alarm threshold (default: 80%)
- `error_rate_threshold` - Error rate alarm threshold (default: 10)
- `memory_threshold` - Memory utilization alarm threshold (default: 85%)
- `alarm_evaluation_periods` - Number of evaluation periods (default: 2)
- `alarm_period` - Alarm period in seconds (default: 60)

### Lambda Configuration

- `lambda_log_level` - Log level for Lambda functions (default: INFO)
- `lambda_architecture` - CPU architecture (default: arm64)
- `lambda_memory_sizes` - Memory allocation per function (object)
- `lambda_timeout_seconds` - Timeout per function (object)

### Data Collection

- `metrics_lookback_minutes` - Metrics collection window (default: 60)
- `logs_lookback_minutes` - Logs collection window (default: 30)
- `changes_lookback_hours` - Changes collection window (default: 24)
- `max_log_entries` - Maximum log entries per incident (default: 100)
- `max_context_size_bytes` - Maximum context size for LLM (default: 51200)

### LLM Configuration

- `bedrock_model_id` - Bedrock model ID (default: anthropic.claude-v2)
- `bedrock_model_temperature` - LLM temperature (default: 0.3)
- `bedrock_max_tokens` - Maximum tokens for response (default: 1000)
- `prompt_template_parameter_name` - SSM parameter for prompt template

### Storage and Retention

- `dynamodb_table_name` - DynamoDB table name (default: incident-analysis-store)
- `dynamodb_billing_mode` - Billing mode (default: PAY_PER_REQUEST)
- `incident_retention_days` - Incident TTL in days (default: 90)
- `cloudwatch_log_retention_days` - Log retention (default: 7)

### Security

- `kms_key_deletion_window` - KMS key deletion window (default: 30 days)
- `enable_kms_key_rotation` - Enable KMS key rotation (default: true)
- `secrets_rotation_days` - Secrets rotation interval (default: 90 days)

### Observability

- `enable_xray_tracing` - Enable X-Ray tracing (default: true)
- `enable_detailed_monitoring` - Enable detailed monitoring (default: true)
- `create_cloudwatch_alarms` - Create system alarms (default: true)

## Outputs

### Key Outputs

- `orchestrator_arn` - Step Functions state machine ARN
- `incident_table_name` - DynamoDB table name
- `notification_topic_arn` - SNS topic ARN for notifications
- `lambda_function_arns` - Map of all Lambda function ARNs
- `lambda_function_names` - Map of all Lambda function names

### Integration Outputs

- `integration_config` - Configuration object for external integrations
- `test_configuration` - Configuration for testing the system
- `console_urls` - AWS Console URLs for key resources

### Security Outputs

- `kms_key_arn` - KMS key ARN for encryption
- `slack_secret_arn` - Secrets Manager secret ARN (sensitive)
- `iam_role_arns` - Map of all IAM role ARNs

## Usage

### Initialize Terraform

```bash
cd terraform
terraform init
```

### Validate Configuration

```bash
terraform validate
```

### Plan Deployment

```bash
# Create a terraform.tfvars file with your values
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your configuration

# Plan changes
terraform plan -var="environment=dev"
```

### Deploy Infrastructure

```bash
# Apply changes
terraform apply -var="environment=dev"
```

### Destroy Infrastructure

```bash
terraform destroy -var="environment=dev"
```

## Variable Validation

All variables include validation rules to ensure correct values:

- **Region**: Must match AWS region format (e.g., us-east-1)
- **Environment**: Must be dev, staging, or prod
- **Email addresses**: Must be valid email format
- **Thresholds**: Must be within valid ranges
- **Memory/Timeout**: Must meet AWS Lambda limits
- **Retention periods**: Must match CloudWatch allowed values

## Multi-Environment Deployment

### Using Workspaces

```bash
# Create workspace for each environment
terraform workspace new dev
terraform workspace new staging
terraform workspace new prod

# Switch to workspace
terraform workspace select dev

# Deploy to specific environment
terraform apply -var="environment=dev"
```

### Using Separate State Files

```bash
# Deploy to dev
terraform apply -var="environment=dev" -var-file="environments/dev.tfvars"

# Deploy to prod
terraform apply -var="environment=prod" -var-file="environments/prod.tfvars"
```

## Cost Optimization

The default configuration is optimized for cost efficiency:

- **Lambda**: ARM64 architecture (20% cost reduction)
- **Step Functions**: Express Workflows (5x cheaper than Standard)
- **DynamoDB**: On-demand billing (no provisioned capacity)
- **CloudWatch Logs**: 7-day retention
- **Incident Records**: 90-day TTL

Estimated monthly cost for low-volume usage: **$5-15**

## Security Best Practices

- All resources use least-privilege IAM roles
- Data encrypted at rest with KMS
- Secrets stored in Secrets Manager
- No hardcoded credentials
- LLM has explicit deny for mutating APIs
- X-Ray tracing enabled for observability

## Testing

Infrastructure tests are located in `tests/infrastructure/`:

```bash
# Run infrastructure tests
pytest tests/infrastructure/test_terraform_variables.py -v
```

## Troubleshooting

### Common Issues

**Issue**: Terraform state lock error
**Solution**: Check for existing locks in S3/DynamoDB backend

**Issue**: Insufficient IAM permissions
**Solution**: Ensure AWS credentials have permissions to create all resources

**Issue**: Resource name conflicts
**Solution**: Change `project_name` variable to use unique prefix

**Issue**: Lambda deployment package not found
**Solution**: Build Lambda packages first (see main README)

## Additional Resources

- [AWS Step Functions Documentation](https://docs.aws.amazon.com/step-functions/)
- [Amazon Bedrock Documentation](https://docs.aws.amazon.com/bedrock/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Project Design Document](../docs/DESIGN.md)

## Support

For issues or questions, refer to the main project README or create an issue in the repository.
