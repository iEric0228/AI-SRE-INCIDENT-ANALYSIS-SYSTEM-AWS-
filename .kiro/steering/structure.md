# Project Structure

## Directory Organization

```
.
├── .kiro/
│   ├── specs/
│   │   └── ai-sre-incident-analysis/
│   │       ├── requirements.md    # Feature requirements and acceptance criteria
│   │       ├── design.md          # Technical design and architecture
│   │       └── tasks.md           # Implementation task list
│   └── steering/                  # Project guidance documents
│       ├── product.md             # Product overview
│       ├── tech.md                # Tech stack and commands
│       └── structure.md           # This file
├── terraform/                     # Infrastructure as Code (to be created)
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── modules/
│   │   ├── lambda/
│   │   ├── step-functions/
│   │   ├── dynamodb/
│   │   └── eventbridge/
│   └── environments/
│       ├── dev/
│       ├── staging/
│       └── prod/
├── src/                           # Lambda function source code (to be created)
│   ├── metrics_collector/
│   │   ├── lambda_function.py
│   │   └── requirements.txt
│   ├── logs_collector/
│   │   ├── lambda_function.py
│   │   └── requirements.txt
│   ├── deploy_context_collector/
│   │   ├── lambda_function.py
│   │   └── requirements.txt
│   ├── correlation_engine/
│   │   ├── lambda_function.py
│   │   └── requirements.txt
│   ├── llm_analyzer/
│   │   ├── lambda_function.py
│   │   └── requirements.txt
│   ├── notification_service/
│   │   ├── lambda_function.py
│   │   └── requirements.txt
│   └── shared/                    # Shared utilities and data models
│       ├── models.py
│       ├── utils.py
│       └── aws_clients.py
├── tests/                         # Test suite (to be created)
│   ├── unit/
│   ├── property/
│   ├── integration/
│   ├── infrastructure/
│   └── conftest.py
├── .github/
│   └── workflows/                 # CI/CD pipelines (to be created)
│       ├── terraform-validate.yml
│       ├── test.yml
│       └── deploy.yml
└── docs/                          # Additional documentation (to be created)
    ├── README.md
    ├── DESIGN.md
    └── DEMO.md
```

## Component Organization

### Lambda Functions

Each Lambda function is self-contained in its own directory under `src/`:

- **metrics_collector**: Queries CloudWatch Metrics API
- **logs_collector**: Queries CloudWatch Logs API
- **deploy_context_collector**: Queries CloudTrail and SSM Parameter Store
- **correlation_engine**: Merges and normalizes collector outputs
- **llm_analyzer**: Invokes Amazon Bedrock for root-cause analysis
- **notification_service**: Sends alerts to Slack and email

### Shared Code

The `src/shared/` directory contains:

- **models.py**: Data classes for incident events, metrics, logs, analysis reports
- **utils.py**: Common utilities (time range calculation, JSON serialization, logging)
- **aws_clients.py**: Boto3 client initialization with retry configuration

### Terraform Modules

Infrastructure is organized into reusable Terraform modules:

- **lambda**: Lambda function, IAM role, CloudWatch log group
- **step-functions**: State machine definition, IAM role, CloudWatch logs
- **dynamodb**: Table, GSIs, TTL configuration, KMS encryption
- **eventbridge**: Event rules, SNS topics, subscriptions

### Test Organization

Tests mirror the source structure:

- **unit/**: One test file per Lambda function
- **property/**: Property-based tests grouped by component
- **integration/**: End-to-end workflow tests
- **infrastructure/**: Terraform and IAM policy validation tests

## File Naming Conventions

- Lambda handlers: `lambda_function.py` (AWS convention)
- Test files: `test_<component_name>.py`
- Terraform files: `<resource_type>.tf` or `main.tf` for modules
- Data models: Use dataclasses with snake_case attributes
- Functions: snake_case
- Classes: PascalCase
- Constants: UPPER_SNAKE_CASE

## Configuration Files

- **requirements.txt**: Per-function Python dependencies
- **terraform.tfvars**: Environment-specific Terraform variables
- **pytest.ini**: Test configuration and markers
- **.github/workflows/*.yml**: CI/CD pipeline definitions

## Documentation Standards

- **README.md**: Setup instructions, architecture diagram, usage examples
- **DESIGN.md**: Architecture patterns, technology choices, trade-offs
- **DEMO.md**: Sample incidents, expected outputs, screenshots
- Inline code comments for complex logic
- Docstrings for all public functions and classes

## Current State

The project is in the planning phase with complete specification documents in `.kiro/specs/ai-sre-incident-analysis/`. Implementation will follow the task list in `tasks.md`.
