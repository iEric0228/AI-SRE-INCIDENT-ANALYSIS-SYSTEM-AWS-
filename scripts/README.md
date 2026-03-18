# Scripts Directory

This directory contains utility scripts for setting up and managing the AI-Assisted SRE Incident Analysis System.

## Available Scripts

### create_prompt_template.py

Creates and stores the LLM prompt template in AWS Systems Manager Parameter Store.

**Purpose**: Initialize the prompt template that guides the Amazon Bedrock Claude model in analyzing incidents.

**Prerequisites**:
- AWS credentials configured (`aws configure`)
- IAM permissions for `ssm:PutParameter` and `ssm:GetParameter`
- Python 3.11+ with boto3 installed

**Usage**:
```bash
python scripts/create_prompt_template.py
```

**What it does**:
1. Creates parameter at `/incident-analysis/prompt-template`
2. Tags parameter with project metadata
3. Verifies parameter was created successfully
4. Displays parameter details and version

**Output**:
```
================================================================================
Creating LLM Prompt Template in Parameter Store
================================================================================

Parameter Name: /incident-analysis/prompt-template
Template Version: v1.0
Template Size: 3456 characters

✓ Connected to AWS Systems Manager

Creating parameter...
✓ Successfully created parameter: /incident-analysis/prompt-template
  Version: 1
  Template Version: v1.0

Verifying parameter...

✓ Parameter verification successful:
  Name: /incident-analysis/prompt-template
  Type: String
  Version: 1
  Last Modified: 2024-01-15 14:30:00
  Size: 3456 characters
  ✓ All required sections present

================================================================================
✓ Prompt template successfully created and verified!
================================================================================
```

**Updating the template**:
1. Edit `create_prompt_template.py`
2. Increment `PROMPT_VERSION` (e.g., v1.0 → v1.1)
3. Update `PROMPT_TEMPLATE` content
4. Run the script again

Parameter Store will maintain version history automatically.

**Testing**:
The template structure is validated by unit tests:
```bash
pytest tests/unit/test_prompt_template.py -v
```

**Troubleshooting**:

| Error | Solution |
|-------|----------|
| `NoCredentialsError` | Run `aws configure` to set up credentials |
| `AccessDeniedException` | Ensure IAM user/role has `ssm:PutParameter` permission |
| `ParameterAlreadyExists` | Script uses `Overwrite=True`, so this shouldn't occur |
| `ValidationException` | Check parameter name format (must start with `/`) |

**Related Documentation**:
- [docs/PROMPT_TEMPLATE.md](../docs/PROMPT_TEMPLATE.md) - Detailed prompt template documentation

### trigger-test-alarm.sh

SSHes into the test EC2 instance and runs `stress-ng` to spike CPU, triggering the CloudWatch alarm and the full incident analysis pipeline.

```bash
./scripts/trigger-test-alarm.sh
```

### reset-test-alarm.sh

Resets the test CloudWatch alarm back to OK state after testing.

```bash
./scripts/reset-test-alarm.sh
```

### capture-alarm-event.sh

Captures a raw EventBridge/CloudWatch alarm event from CloudWatch Logs for use as test data.

```bash
./scripts/capture-alarm-event.sh
```

### package-lambdas.sh

Packages all Lambda functions into deployment ZIPs with dependencies for ARM64 architecture.

```bash
./scripts/package-lambdas.sh
```

### setup-github-oidc.sh

Sets up GitHub Actions OIDC authentication with AWS for keyless CI/CD deployments.

```bash
./scripts/setup-github-oidc.sh
```

## Script Organization

```
scripts/
├── README.md                  # This file
├── create_prompt_template.py  # LLM prompt template setup
├── trigger-test-alarm.sh      # Trigger test alarm via CPU stress
├── reset-test-alarm.sh        # Reset test alarm to OK state
├── capture-alarm-event.sh     # Capture EventBridge event payload
├── package-lambdas.sh         # Package Lambda deployment ZIPs
└── setup-github-oidc.sh       # Configure GitHub OIDC for CI/CD
```
