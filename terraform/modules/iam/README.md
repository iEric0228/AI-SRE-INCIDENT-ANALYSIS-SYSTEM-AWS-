# IAM Roles and Policies Module

This Terraform module creates least-privilege IAM roles for all Lambda functions and the Step Functions orchestrator in the AI-Assisted SRE Incident Analysis System.

## Security Design

The module follows the principle of least privilege, granting each component only the minimum permissions required for its function. The LLM Analyzer has the most restrictive policy with explicit denies for mutating AWS APIs.

## Resources Created

### Lambda Function Roles

1. **Metrics Collector Role**
   - Permissions: `cloudwatch:GetMetricStatistics`, `cloudwatch:ListMetrics`
   - Purpose: Query CloudWatch Metrics API for resource metrics

2. **Logs Collector Role**
   - Permissions: `logs:FilterLogEvents`, `logs:DescribeLogGroups`, `logs:DescribeLogStreams`
   - Purpose: Query CloudWatch Logs API for error logs

3. **Deploy Context Collector Role**
   - Permissions: `ssm:GetParameter`, `ssm:GetParameterHistory`, `cloudtrail:LookupEvents`
   - Purpose: Query CloudTrail and SSM Parameter Store for deployment context

4. **Correlation Engine Role**
   - Permissions: CloudWatch Logs write only
   - Purpose: Merge and normalize collector outputs (no AWS API calls)

5. **LLM Analyzer Role** (MOST RESTRICTIVE)
   - Permissions: `bedrock:InvokeModel`, `ssm:GetParameter` (prompt template only)
   - Explicit Denies: `ec2:*`, `rds:*`, `iam:*`, `s3:Delete*`, `s3:Put*`, `dynamodb:Delete*`, `dynamodb:Update*`, `dynamodb:Put*`, `lambda:Update*`, `lambda:Delete*`, `lambda:Create*`, `lambda:Put*`, `cloudformation:*`, `sts:AssumeRole`
   - Purpose: Invoke Amazon Bedrock for analysis (advisory-only, no infrastructure mutation)

6. **Notification Service Role**
   - Permissions: `secretsmanager:GetSecretValue`, `sns:Publish`
   - Purpose: Retrieve Slack webhook from Secrets Manager and publish to SNS

### Step Functions Orchestrator Role

- Permissions: `lambda:InvokeFunction` (specific functions only), `dynamodb:PutItem`, `xray:PutTraceSegments`, `xray:PutTelemetryRecords`
- Purpose: Orchestrate workflow, invoke Lambda functions, store incidents, emit traces

## Usage

```hcl
module "iam" {
  source = "./modules/iam"

  project_name   = "ai-sre-incident-analysis"
  aws_region     = "us-east-1"
  aws_account_id = data.aws_caller_identity.current.account_id

  tags = {
    Project     = "AI-SRE-Portfolio"
    Environment = "dev"
  }
}

# Use role ARNs in Lambda function definitions
resource "aws_lambda_function" "metrics_collector" {
  function_name = "${var.project_name}-metrics-collector"
  role          = module.iam.metrics_collector_role_arn
  # ... other configuration
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| project_name | Project name used for resource naming | string | "ai-sre-incident-analysis" | no |
| aws_region | AWS region where resources are deployed | string | - | yes |
| aws_account_id | AWS account ID | string | - | yes |
| tags | Tags to apply to all IAM resources | map(string) | {"Project": "AI-SRE-Portfolio"} | no |

## Outputs

| Name | Description |
|------|-------------|
| metrics_collector_role_arn | ARN of the Metrics Collector Lambda IAM role |
| logs_collector_role_arn | ARN of the Logs Collector Lambda IAM role |
| deploy_context_collector_role_arn | ARN of the Deploy Context Collector Lambda IAM role |
| correlation_engine_role_arn | ARN of the Correlation Engine Lambda IAM role |
| llm_analyzer_role_arn | ARN of the LLM Analyzer Lambda IAM role |
| notification_service_role_arn | ARN of the Notification Service Lambda IAM role |
| orchestrator_role_arn | ARN of the Step Functions Orchestrator IAM role |
| lambda_role_arns | Map of all Lambda function role ARNs |

## Security Considerations

### Least Privilege

Each role has only the minimum permissions required:
- Read-only permissions for data collectors
- No cross-service permissions (each function accesses only its required services)
- Scoped resource ARNs where possible (e.g., specific log groups, parameter paths)

### LLM Analyzer Restrictions

The LLM Analyzer has explicit deny policies to prevent infrastructure mutation:
- Cannot create, update, or delete EC2 instances
- Cannot modify RDS databases
- Cannot change IAM policies
- Cannot delete or modify S3 objects
- Cannot update or delete Lambda functions
- Cannot assume other IAM roles

This ensures the AI remains advisory-only and cannot make changes to infrastructure.

### CloudWatch Logs

All roles include permissions to write to their own CloudWatch Log Groups only, scoped by function name pattern.

## Validation

To validate IAM policies:

```bash
# Validate Terraform configuration
terraform validate

# Check policy syntax
terraform plan

# Review generated policies
terraform show
```

## Requirements Validation

This module validates the following requirements:

- **10.1**: Metrics Collector has only CloudWatch Metrics read permissions
- **10.2**: Logs Collector has only CloudWatch Logs read permissions
- **10.3**: Deploy Context Collector has only SSM and CloudTrail read permissions
- **10.4**: LLM Analyzer has only Bedrock InvokeModel permission
- **10.5**: LLM Analyzer has explicit denies for EC2, RDS, IAM, and mutating APIs
- **10.6**: Notification Service has only SNS Publish and Secrets Manager read permissions
- **10.7**: Orchestrator has only Lambda invoke permissions for specific functions

## Testing

See `tests/infrastructure/test_iam_policies.py` for IAM policy validation tests.
