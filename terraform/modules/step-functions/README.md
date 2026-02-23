# Step Functions State Machine Module

This Terraform module creates an AWS Step Functions Express Workflow that orchestrates the AI-assisted incident analysis pipeline.

## Overview

The state machine coordinates parallel data collection, correlation, LLM analysis, and notification/storage in a fault-tolerant workflow with graceful degradation.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                  Parallel Data Collection                    │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   Metrics    │  │     Logs     │  │    Deploy    │      │
│  │  Collector   │  │  Collector   │  │   Context    │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
                  ┌──────────────────┐
                  │   Correlation    │
                  │     Engine       │
                  └──────────────────┘
                            │
                            ▼
                  ┌──────────────────┐
                  │   LLM Analyzer   │
                  └──────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│              Parallel Notification & Storage                 │
│  ┌──────────────────────┐  ┌──────────────────────┐        │
│  │   Notification       │  │   DynamoDB Storage   │        │
│  │   Service            │  │                      │        │
│  └──────────────────────┘  └──────────────────────┘        │
└─────────────────────────────────────────────────────────────┘
```

## Features

- **Express Workflow**: Low-latency, cost-efficient execution (5x cheaper than Standard)
- **Parallel Data Collection**: Three collectors run simultaneously to minimize latency
- **Graceful Degradation**: Workflow continues with partial data if collectors fail
- **Retry Policies**: Exponential backoff for transient errors (3 attempts, 2s/4s/8s)
- **Timeout Protection**: 120-second total workflow timeout
- **CloudWatch Logging**: Full execution data logged for debugging
- **X-Ray Tracing**: Distributed tracing enabled for performance analysis

## State Machine Flow

1. **ParallelDataCollection**: Invokes three Lambda collectors in parallel
   - Metrics Collector (20s timeout)
   - Logs Collector (20s timeout)
   - Deploy Context Collector (20s timeout)
   - Each branch has independent error handling

2. **CorrelateData**: Merges collector outputs into structured context (10s timeout)
   - Handles missing data from failed collectors
   - Marks completeness status

3. **AnalyzeWithLLM**: Generates root-cause hypothesis (40s timeout)
   - Retries on throttling errors
   - Falls back to error notification if analysis fails

4. **NotifyAndStore**: Parallel notification and persistence
   - Notification Service (15s timeout)
   - DynamoDB PutItem (direct integration)
   - Independent error handling for each branch

## Error Handling

### Retryable Errors
- `ThrottlingException`: AWS API rate limits
- `ServiceException`: Temporary AWS service issues
- `TooManyRequestsException`: Bedrock rate limits
- `ProvisionedThroughputExceededException`: DynamoDB throttling

### Retry Configuration
- **Interval**: 2 seconds initial
- **Max Attempts**: 3
- **Backoff Rate**: 2.0 (exponential: 2s, 4s, 8s)

### Graceful Degradation
- Collector failures don't block workflow
- Failed collectors return error markers
- Correlation engine handles partial data
- LLM failure still triggers notification
- Notification failure still persists to DynamoDB

## Usage

```hcl
module "step_functions" {
  source = "./modules/step-functions"

  project_name            = "ai-sre-incident-analysis"
  state_machine_role_arn  = module.iam.state_machine_role_arn
  dynamodb_table_name     = module.dynamodb.table_name

  lambda_function_arns = {
    metrics_collector        = module.lambda.metrics_collector_arn
    logs_collector           = module.lambda.logs_collector_arn
    deploy_context_collector = module.lambda.deploy_context_collector_arn
    correlation_engine       = module.lambda.correlation_engine_arn
    llm_analyzer             = module.lambda.llm_analyzer_arn
    notification_service     = module.lambda.notification_service_arn
  }

  tags = {
    Project     = "AI-SRE-Portfolio"
    Environment = "production"
  }
}
```

## Inputs

| Name | Description | Type | Required |
|------|-------------|------|----------|
| `project_name` | Project name for resource naming | `string` | No (default: "ai-sre-incident-analysis") |
| `state_machine_role_arn` | IAM role ARN for state machine | `string` | Yes |
| `lambda_function_arns` | Map of Lambda function ARNs | `object` | Yes |
| `dynamodb_table_name` | DynamoDB incident store table name | `string` | Yes |
| `tags` | Tags to apply to resources | `map(string)` | No |

## Outputs

| Name | Description |
|------|-------------|
| `state_machine_arn` | ARN of the Step Functions state machine |
| `state_machine_name` | Name of the state machine |
| `state_machine_id` | ID of the state machine |
| `log_group_arn` | CloudWatch Log Group ARN |
| `log_group_name` | CloudWatch Log Group name |

## IAM Permissions Required

The state machine role needs:
- `lambda:InvokeFunction` on all six Lambda functions
- `dynamodb:PutItem` on the incident store table
- `xray:PutTraceSegments` and `xray:PutTelemetryRecords` for tracing
- `logs:CreateLogGroup`, `logs:CreateLogStream`, `logs:PutLogEvents` for logging

## Monitoring

### CloudWatch Logs
- Log Group: `/aws/vendedlogs/states/{project_name}-orchestrator`
- Retention: 7 days
- Includes full execution data for debugging

### X-Ray Tracing
- Enabled for distributed tracing
- Visualize workflow execution and identify bottlenecks

### Metrics to Monitor
- `ExecutionsFailed`: Failed workflow executions
- `ExecutionThrottled`: Throttled executions
- `ExecutionTime`: Workflow duration (should be < 120s)

## Cost Optimization

- **Express Workflow**: ~$1.00 per million requests (vs $25 for Standard)
- **7-day log retention**: Minimizes storage costs
- **120-second timeout**: Prevents runaway executions

## Validation Requirements

This module validates:
- Requirements 2.1: Parallel collector invocation
- Requirements 2.2, 2.3, 2.4: Workflow sequencing
- Requirements 2.5: Graceful degradation with partial data
- Requirements 2.6: Workflow timeout (120 seconds)
- Requirements 17.1: Express Workflow type
- Requirements 20.1, 20.2: Retry policies and error classification

## Testing

Run infrastructure tests:
```bash
pytest tests/infrastructure/test_step_functions_configuration.py
```

Validate Terraform configuration:
```bash
cd terraform/modules/step-functions
terraform init
terraform validate
```

## References

- [AWS Step Functions Express Workflows](https://docs.aws.amazon.com/step-functions/latest/dg/concepts-standard-vs-express.html)
- [Error Handling in Step Functions](https://docs.aws.amazon.com/step-functions/latest/dg/concepts-error-handling.html)
- [Step Functions Service Integrations](https://docs.aws.amazon.com/step-functions/latest/dg/concepts-service-integrations.html)

