# Technology Stack

## Infrastructure

- **Cloud Platform**: AWS
- **Infrastructure as Code**: Terraform
- **Orchestration**: AWS Step Functions (Express Workflows)
- **Compute**: AWS Lambda (Python 3.11+, ARM64/Graviton2)
- **Storage**: DynamoDB (on-demand billing)
- **Event Bus**: Amazon EventBridge + SNS
- **AI/ML**: Amazon Bedrock (Claude model)
- **Secrets**: AWS Secrets Manager
- **Configuration**: AWS Systems Manager Parameter Store
- **Observability**: CloudWatch (Logs, Metrics, Alarms), X-Ray

## Development Stack

- **Language**: Python 3.11+
- **AWS SDK**: boto3
- **Testing**: pytest, Hypothesis (property-based testing), moto (AWS mocking)
- **CI/CD**: GitHub Actions with OIDC authentication
- **HTTP Client**: requests (for Slack webhooks)

## Architecture Patterns

- Event-driven architecture with loose coupling
- Parallel fan-out for data collection
- Correlation layer for data normalization
- Advisory-only AI (no infrastructure mutation permissions)
- Graceful degradation with partial failure handling
- Circuit breaker pattern for external services

## Common Commands

### Terraform

```bash
# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Plan changes
terraform plan

# Apply changes
terraform apply

# Destroy resources
terraform destroy
```

### Testing

```bash
# Run all tests
pytest

# Run unit tests only
pytest tests/unit/

# Run property tests with full iterations
HYPOTHESIS_PROFILE=ci pytest tests/property/

# Run with coverage
pytest --cov=src --cov-report=html

# Run specific test file
pytest tests/unit/test_metrics_collector.py
```

### Lambda Development

```bash
# Install dependencies
pip install -r requirements.txt

# Run local tests
pytest tests/

# Package Lambda function
zip -r function.zip lambda_function.py dependencies/
```

## Configuration Standards

- All Lambda functions use ARM64 architecture for cost efficiency
- Step Functions use Express Workflows (not Standard) for lower cost
- CloudWatch Logs retention: 7 days
- DynamoDB TTL: 90 days for incident records
- All resources tagged with "Project: AI-SRE-Portfolio"
- Secrets stored in Secrets Manager (never in environment variables)
- Prompt templates stored in Parameter Store for versioning

## Security Requirements

- Least-privilege IAM roles per Lambda function
- LLM Analyzer has explicit deny for mutating AWS APIs
- No long-lived credentials (use OIDC for CI/CD)
- All data encrypted at rest (KMS)
- Secrets retrieved at runtime only
- No PII or sensitive data in logs
