# Scripts Directory

This directory contains utility scripts for setting up and managing the AI-Assisted SRE Incident Analysis System.

## Available Scripts

### create_prompt_template.py

Creates and stores the LLM prompt template in AWS Systems Manager Parameter Store.

**Purpose**: Initialize the prompt template that guides the Amazon Bedrock Claude model in analyzing incidents.

**Requirements**: 16.1, 16.2, 16.3, 16.4, 16.5

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
- [.kiro/specs/ai-sre-incident-analysis/requirements.md](../.kiro/specs/ai-sre-incident-analysis/requirements.md) - Requirement 16

## Future Scripts

Additional scripts will be added as the project progresses:

- `trigger-test-alarm.sh` - Trigger test CloudWatch Alarm for development
- `capture-alarm-event.sh` - Extract EventBridge event from CloudWatch Logs
- `reset-test-alarm.sh` - Return test alarm to OK state
- `deploy-infrastructure.sh` - Deploy Terraform infrastructure
- `run-integration-tests.sh` - Execute end-to-end integration tests

## Development Guidelines

When adding new scripts:

1. **Naming**: Use descriptive names with underscores (Python) or hyphens (Bash)
2. **Shebang**: Include appropriate shebang (`#!/usr/bin/env python3` or `#!/bin/bash`)
3. **Documentation**: Add docstring/comments explaining purpose and usage
4. **Error Handling**: Include proper error handling and user-friendly messages
5. **Permissions**: Make scripts executable (`chmod +x script.sh`)
6. **Testing**: Add unit tests for Python scripts where applicable
7. **README**: Update this README with script documentation

## Script Organization

```
scripts/
├── README.md                      # This file
├── create_prompt_template.py      # LLM prompt template setup
├── trigger-test-alarm.sh          # (Future) Trigger test alarm
├── capture-alarm-event.sh         # (Future) Capture EventBridge event
└── reset-test-alarm.sh            # (Future) Reset test alarm
```
