# Terraform Deployment Guide

This document provides instructions for deploying the AI-Assisted SRE Incident Analysis System infrastructure using Terraform.

## Prerequisites

- Terraform >= 1.5.0
- AWS CLI configured with appropriate credentials
- AWS account with permissions to create:
  - IAM roles and policies
  - Lambda functions
  - DynamoDB tables
  - Step Functions state machines
  - EventBridge rules
  - SNS topics
  - Secrets Manager secrets
  - KMS keys
  - CloudWatch alarms and dashboards

## Architecture Overview

The Terraform configuration instantiates the following modules:

1. **Secrets Module**: Creates KMS key and Secrets Manager secrets for Slack/email configuration
2. **IAM Module**: Creates least-privilege IAM roles for all Lambda functions and Step Functions
3. **DynamoDB Module**: Creates incident store table with GSIs and TTL
4. **EventBridge Module**: Creates event rules and SNS topics for alarm routing
5. **Lambda Module**: Creates all 6 Lambda functions with CloudWatch log groups
6. **Step Functions Module**: Creates Express Workflow orchestrator
7. **CloudWatch Alarms Module**: Creates monitoring alarms and dashboard

## Backend Configuration

The configuration uses S3 backend for remote state storage with workspace support:

```hcl
backend "s3" {
  bucket         = "ai-sre-incident-analysis-terraform-state"
  key            = "incident-analysis/terraform.tfstate"
  region         = "us-east-1"
  encrypt        = true
  dynamodb_table = "terraform-state-lock"
  workspace_key_prefix = "env"
}
```

### Setting Up the Backend

Before running Terraform, create the S3 bucket and DynamoDB table for state management:

```bash
# Create S3 bucket for state storage
aws s3api create-bucket \
  --bucket ai-sre-incident-analysis-terraform-state \
  --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket ai-sre-incident-analysis-terraform-state \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket ai-sre-incident-analysis-terraform-state \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

## Workspace Management

The configuration supports multiple environments via Terraform workspaces:

```bash
# List workspaces
terraform workspace list

# Create and switch to dev workspace
terraform workspace new dev

# Switch to existing workspace
terraform workspace select staging

# Show current workspace
terraform workspace show
```

## Deployment Steps

### 1. Initialize Terraform

```bash
cd terraform
terraform init
```

### 2. Create Lambda Deployment Packages

Before deploying, package the Lambda functions:

```bash
# From project root
cd src/metrics_collector
zip -r deployment.zip lambda_function.py
cd ../..

# Repeat for all Lambda functions:
# - logs_collector
# - deploy_context_collector
# - correlation_engine
# - llm_analyzer
# - notification_service
```

### 3. Configure Variables

Create a `terraform.tfvars` file (use `terraform.tfvars.example` as template):

```hcl
# Core Configuration
aws_region   = "us-east-1"
environment  = "dev"
project_name = "ai-sre-incident-analysis"

# Notification Configuration
email_notification_endpoints = ["oncall@example.com"]

# Lambda Configuration
lambda_log_level = "INFO"

# Tags
additional_tags = {
  Owner = "your-name"
  Team  = "platform-engineering"
}
```

### 4. Validate Configuration

```bash
terraform validate
```

### 5. Plan Deployment

```bash
terraform plan -out=tfplan
```

Review the plan carefully to ensure all resources will be created as expected.

### 6. Apply Configuration

```bash
terraform apply tfplan
```

### 7. Post-Deployment Configuration

After deployment, update the Secrets Manager secrets with actual values:

```bash
# Update Slack webhook URL
aws secretsmanager update-secret \
  --secret-id ai-sre-incident-analysis-slack-webhook \
  --secret-string '{"webhook_url":"https://hooks.slack.com/services/YOUR/WEBHOOK/URL"}'

# Update email configuration
aws secretsmanager update-secret \
  --secret-id ai-sre-incident-analysis-email-config \
  --secret-string '{
    "from_address":"incidents@example.com",
    "recipients":["oncall@example.com"]
  }'
```

### 8. Create Prompt Template

Store the LLM prompt template in Parameter Store:

```bash
aws ssm put-parameter \
  --name "/ai-sre-incident-analysis/prompt-template" \
  --type "String" \
  --value "$(cat ../docs/PROMPT_TEMPLATE.md)" \
  --description "LLM prompt template for incident analysis" \
  --tags "Key=Project,Value=AI-SRE-Portfolio"
```

## Environment-Specific Deployments

### Development Environment

```bash
terraform workspace select dev
terraform apply -var="environment=dev" -var="lambda_log_level=DEBUG"
```

### Staging Environment

```bash
terraform workspace select staging
terraform apply -var="environment=staging"
```

### Production Environment

```bash
terraform workspace select prod
terraform apply -var="environment=prod" -var="create_cloudwatch_alarms=true"
```

## Outputs

After deployment, Terraform provides key resource identifiers:

```bash
# View all outputs
terraform output

# View specific output
terraform output orchestrator_arn
terraform output incident_store_table_name
terraform output notification_topic_arn
```

## Resource Tagging

All resources are tagged with:

- `Project: AI-SRE-Portfolio`
- `ManagedBy: Terraform`
- `Purpose: Incident-Analysis`
- `Environment: <workspace>`
- `Workspace: <terraform-workspace>`

Additional tags can be specified via the `additional_tags` variable.

## Cost Optimization

The configuration follows AWS cost optimization best practices:

- Lambda functions use ARM64 (Graviton2) architecture
- Step Functions uses Express Workflows (not Standard)
- DynamoDB uses on-demand billing
- CloudWatch Logs retention set to 7 days
- Lambda memory sizes optimized per function

Estimated monthly cost for low-volume usage: **$5-15**

## Troubleshooting

### Circular Dependency Errors

If you encounter circular dependency errors, ensure modules are created in the correct order:
1. Secrets (KMS key)
2. IAM roles
3. DynamoDB
4. EventBridge (without alarm notification)
5. Lambda
6. Step Functions
7. CloudWatch Alarms

### Lambda Deployment Package Not Found

Ensure all Lambda deployment packages exist before running `terraform apply`:

```bash
ls -la ../src/*/deployment.zip
```

### State Lock Errors

If state is locked, identify and release the lock:

```bash
# List locks
aws dynamodb scan --table-name terraform-state-lock

# Force unlock (use with caution)
terraform force-unlock <lock-id>
```

## Cleanup

To destroy all resources:

```bash
# Destroy resources in current workspace
terraform destroy

# Destroy specific workspace
terraform workspace select dev
terraform destroy
```

**Warning**: This will permanently delete all infrastructure including the DynamoDB incident store.

## Security Considerations

- Never commit `terraform.tfvars` with sensitive values
- Use AWS Secrets Manager for all credentials
- Review IAM policies before deployment
- Enable CloudTrail for audit logging
- Rotate secrets regularly (90-day default)

## Next Steps

After deployment:

1. Test the system with the test scenario infrastructure (`terraform/test-scenario/`)
2. Configure CloudWatch Alarms to trigger incident analysis
3. Review CloudWatch Dashboard for system health
4. Set up CI/CD pipeline for automated deployments

## Support

For issues or questions:
- Review the main [README.md](../README.md)
- Check [DESIGN.md](../docs/DESIGN.md) for architecture details
- See [DEMO.md](../docs/DEMO.md) for usage examples
