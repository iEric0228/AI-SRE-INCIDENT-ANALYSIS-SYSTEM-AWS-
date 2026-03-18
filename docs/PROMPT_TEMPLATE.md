# LLM Prompt Template Documentation

## Overview

The LLM prompt template is a structured instruction set stored in AWS Systems Manager Parameter Store that guides the Amazon Bedrock Claude model in analyzing incident data and generating root-cause hypotheses.

**Parameter Store Path**: `/incident-analysis/prompt-template`  
**Current Version**: v1.0  
**Requirements**: 16.1, 16.2, 16.3, 16.4, 16.5

## Template Structure

The prompt template consists of the following sections:

### 1. Role Definition
Establishes the LLM's persona as an expert Site Reliability Engineer with deep AWS and distributed systems knowledge.

### 2. Task Description
Clearly defines the objective: analyze incident data and generate evidence-based root-cause hypotheses.

### 3. Input Format
Specifies that the LLM will receive a `{structured_context}` placeholder that will be replaced with actual incident data at runtime.

### 4. Output Format
Defines the expected JSON structure:
```json
{
  "rootCauseHypothesis": "string",
  "confidence": "high|medium|low",
  "evidence": ["string", "..."],
  "contributingFactors": ["string", "..."],
  "recommendedActions": ["string", "..."]
}
```

### 5. Instructions

#### Root Cause Hypothesis
- Single clear sentence describing the most likely root cause
- Based only on provided data (no speculation)
- Focus on immediate technical cause, not symptoms

#### Confidence Levels
- **HIGH**: Multiple correlated signals point to same root cause
  - Example: deployment + error spike + metric anomaly all time-aligned
- **MEDIUM**: Single strong signal or multiple weak signals
  - Example: error logs show issue but no correlated metric changes
- **LOW**: Data is ambiguous, incomplete, or conflicting
  - Example: metrics show anomaly but no logs or recent changes

#### Evidence Citation
- Cite specific metrics with exact values and timestamps
- Quote relevant error messages from logs
- Reference specific deployment/configuration changes with timestamps
- Show temporal correlation between events
- Provide 2-3 pieces for high confidence, 1-2 for medium/low

#### Contributing Factors
- Secondary factors that amplified the issue
- Environmental conditions (high traffic, resource constraints)
- Pre-existing vulnerabilities

#### Recommended Actions
- 2-5 specific, actionable steps
- Prioritize immediate mitigation over long-term fixes
- Include rollback steps if recent change is implicated
- Be specific with values and commands
- Cover both remediation and investigation

### 6. Constraints
- Keep response under 500 tokens
- Use only information in structured context
- Acknowledge incomplete data in confidence level
- No assumptions about unmentioned systems
- Focus on technical root causes

## Usage

### Creating the Parameter

Run the creation script:
```bash
python scripts/create_prompt_template.py
```

This will:
1. Create the parameter at `/incident-analysis/prompt-template`
2. Tag it with project metadata
3. Verify the parameter was created successfully

### Retrieving in Lambda

The LLM Analyzer Lambda function retrieves the template at runtime:

```python
import boto3

ssm_client = boto3.client('ssm')
response = ssm_client.get_parameter(Name='/incident-analysis/prompt-template')
prompt_template = response['Parameter']['Value']
prompt_version = response['Parameter']['Version']
```

### Injecting Context

Replace the `{structured_context}` placeholder with actual incident data:

```python
import json

structured_context_json = json.dumps(structured_context, indent=2)
prompt = prompt_template.replace('{structured_context}', structured_context_json)
```

### Invoking Bedrock

```python
bedrock_client = boto3.client('bedrock-runtime')

response = bedrock_client.invoke_model(
    modelId='anthropic.claude-v2',
    body=json.dumps({
        'prompt': prompt,
        'temperature': 0.3,
        'max_tokens_to_sample': 1000,
        'stop_sequences': ['</analysis>']
    })
)
```

## Versioning

The template is versioned to track changes over time:

- **Version**: Stored in parameter tags and description
- **Format**: Semantic versioning (v1.0, v1.1, v2.0)
- **History**: Parameter Store maintains version history automatically

### Updating the Template

To update the template:

1. Edit `scripts/create_prompt_template.py`
2. Increment `PROMPT_VERSION` (e.g., v1.0 → v1.1)
3. Update `PROMPT_TEMPLATE` content
4. Run the script: `python scripts/create_prompt_template.py`
5. The LLM Analyzer will automatically use the new version on next invocation

### Version History

| Version | Date | Changes |
|---------|------|---------|
| v1.0 | 2024-01-15 | Initial template with role, task, instructions, and constraints |

## Example Analysis

### Input (Structured Context)
```json
{
  "incidentId": "550e8400-e29b-41d4-a716-446655440000",
  "timestamp": "2024-01-15T14:30:00Z",
  "resource": {
    "arn": "arn:aws:lambda:us-east-1:123456789012:function:my-function",
    "type": "lambda",
    "name": "my-function"
  },
  "alarm": {
    "name": "HighErrorRate",
    "metric": "Errors",
    "threshold": 10
  },
  "metrics": {
    "summary": {"errorRate": 15.5, "avgDuration": 250},
    "timeSeries": [...]
  },
  "logs": {
    "errorCount": 45,
    "topErrors": ["MemoryError: out of memory", "Connection timeout"],
    "entries": [...]
  },
  "changes": {
    "recentDeployments": 1,
    "lastDeployment": "2024-01-15T14:23:00Z",
    "entries": [
      {
        "timestamp": "2024-01-15T14:23:00Z",
        "changeType": "deployment",
        "eventName": "UpdateFunctionCode",
        "user": "arn:aws:iam::123456789012:user/deployer",
        "description": "Lambda function code updated"
      }
    ]
  },
  "completeness": {
    "metrics": true,
    "logs": true,
    "changes": true
  }
}
```

### Expected Output
```json
{
  "rootCauseHypothesis": "Lambda function exhausted memory due to memory leak in recent deployment",
  "confidence": "high",
  "evidence": [
    "Memory utilization increased from 60% to 95% after deployment at 14:23",
    "Error logs show 'MemoryError: out of memory' starting at 14:25",
    "Deployment occurred 2 minutes before incident at 14:23",
    "Error rate jumped from 0.1% to 15.5% immediately after deployment"
  ],
  "contributingFactors": [
    "Increased traffic during peak hours",
    "Memory limit not adjusted after code changes"
  ],
  "recommendedActions": [
    "Rollback deployment to previous version using AWS Lambda console or CLI",
    "Increase Lambda memory limit from 512MB to 1024MB to provide headroom",
    "Investigate memory leak in new code by profiling the updated function",
    "Add memory utilization monitoring with lower alarm threshold (80%)",
    "Review deployment process to include memory profiling before production"
  ]
}
```

## Design Rationale

### Why Parameter Store?

1. **Versioning**: Automatic version history for all changes
2. **Runtime Retrieval**: No code deployment needed to update prompts
3. **Security**: IAM-controlled access to prompt templates
4. **Cost**: Free for standard parameters (up to 10,000)
5. **Integration**: Native boto3 support in Lambda

### Why This Structure?

1. **Role Definition**: Establishes context and expertise level
2. **Clear Instructions**: Reduces ambiguity in LLM responses
3. **Confidence Levels**: Helps engineers assess reliability of analysis
4. **Evidence Citation**: Ensures analysis is grounded in data
5. **Actionable Recommendations**: Provides immediate value to on-call engineers

### Temperature Setting

The LLM Analyzer uses `temperature=0.3` for:
- **Deterministic output**: Similar incidents produce similar analyses
- **Reduced hallucination**: Lower temperature = more factual responses
- **Consistency**: Reproducible results for testing and validation

## Testing

The prompt template is validated through property-based tests:

- **Property 18**: Prompt construction includes complete context and follows template format
- **Property 19**: LLM response parsing handles valid and malformed responses
- **Property 20**: Analysis report metadata includes model ID, version, prompt version, token usage, latency

See `tests/property/test_llm_prompt_construction.py` for implementation.

## Troubleshooting

### Parameter Not Found
```
Error: ParameterNotFound
```
**Solution**: Run `python scripts/create_prompt_template.py` to create the parameter.

### Access Denied
```
Error: AccessDeniedException
```
**Solution**: Ensure the Lambda IAM role has `ssm:GetParameter` permission for `/incident-analysis/prompt-template`.

### Invalid JSON Response
If the LLM returns malformed JSON, the analyzer will:
1. Attempt to extract text content
2. Wrap in fallback structure
3. Set confidence to "none"
4. Log the parsing error

### Low Quality Analysis
If analyses are consistently low quality:
1. Review recent incidents and LLM responses
2. Identify patterns in failures (missing evidence, vague recommendations)
3. Update prompt template with more specific instructions
4. Increment version and redeploy
5. Monitor improvement in subsequent incidents

## References

- [AWS Systems Manager Parameter Store Documentation](https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-parameter-store.html)
- [Amazon Bedrock Claude Model Documentation](https://docs.aws.amazon.com/bedrock/latest/userguide/model-parameters-claude.html)
- [Prompt Engineering Best Practices](https://docs.anthropic.com/claude/docs/prompt-engineering)
