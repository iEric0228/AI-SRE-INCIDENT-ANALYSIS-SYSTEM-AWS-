# Source Code

This directory contains all Lambda function implementations for the AI-SRE Incident Analysis System.

## Structure

```
src/
├── metrics_collector/       # Collects CloudWatch metrics
├── logs_collector/          # Collects CloudWatch logs
├── deploy_context_collector/# Collects deployment history
├── correlation_engine/      # Merges and normalizes data
├── llm_analyzer/            # Invokes Bedrock for analysis
├── notification_service/    # Sends Slack/email notifications
└── shared/                  # Shared utilities and models
    ├── models.py           # Data classes
    ├── utils.py            # Common utilities
    └── aws_clients.py      # Boto3 client wrappers
```

## Lambda Function Pattern

Each Lambda function follows this structure:

```
function_name/
├── lambda_function.py      # Handler and main logic
└── requirements.txt        # Function-specific dependencies
```

## Shared Code

The `shared/` directory contains code used by multiple Lambda functions:

- **models.py**: Dataclasses for incident events, metrics, logs, analysis reports
- **utils.py**: Time range calculation, JSON serialization, structured logging
- **aws_clients.py**: Boto3 client initialization with retry configuration

## Development

### Running Tests

```bash
# All tests
pytest

# Specific function
pytest tests/unit/test_metrics_collector.py

# With coverage
pytest --cov=src
```

### Code Quality

```bash
# Lint
make lint

# Format
make format
```

### Local Testing

Each Lambda can be tested locally:

```python
from src.metrics_collector.lambda_function import handler

event = {...}  # Sample event
context = {}   # Mock context

result = handler(event, context)
```

## Deployment

Lambda functions are deployed via Terraform modules in `terraform/modules/lambda/`.

Each function gets:
- Dedicated IAM role with least-privilege permissions
- CloudWatch Log Group with 7-day retention
- ARM64 architecture for cost efficiency
- Environment variables for configuration

## Next Steps

1. Implement data models in `shared/models.py` (Task 2.1)
2. Implement each Lambda function (Tasks 3-10)
3. Write unit tests for each function
4. Write property-based tests
5. Deploy with Terraform
