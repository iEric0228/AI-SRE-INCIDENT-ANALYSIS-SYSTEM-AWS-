# Design Document: AI-Assisted SRE Incident Analysis System

## Table of Contents

- [Introduction](#introduction)
- [Architecture Patterns](#architecture-patterns)
- [Technology Choices](#technology-choices)
- [Trade-offs and Design Decisions](#trade-offs-and-design-decisions)
- [Security Design](#security-design)
- [Data Flow](#data-flow)
- [Scalability and Performance](#scalability-and-performance)
- [Cost Optimization](#cost-optimization)
- [Observability](#observability)
- [Future Enhancements](#future-enhancements)

## Introduction

This document explains the architectural design, technology choices, and trade-offs for the AI-Assisted SRE Incident Analysis System. The system is a portfolio project demonstrating production-grade incident management architecture on AWS, using event-driven patterns, serverless compute, and LLM-powered analysis.

The system automatically detects infrastructure issues via CloudWatch Alarms, orchestrates parallel data collection from multiple sources (metrics, logs, deployment history), correlates the data into structured context, generates root-cause hypotheses using Amazon Bedrock's Claude model, and notifies on-call engineers via Slack and email. The design emphasizes security (least-privilege IAM), observability (structured logging and metrics), and graceful degradation (partial failures don't block the workflow).

**Key Design Principles:**
- **Advisory-Only AI**: The LLM generates recommendations but has no permissions to modify infrastructure
- **Loose Coupling**: Components communicate via events, enabling independent scaling and deployment
- **Graceful Degradation**: The system continues with partial data if components fail
- **Security by Default**: Every component has minimal IAM permissions with explicit denies for dangerous operations
- **Cost-Conscious**: Optimized for portfolio project economics while maintaining production patterns

## Architecture Patterns

### Event-Driven Architecture

The system uses event-driven architecture where components communicate through events rather than direct invocation. This provides several benefits:

**Loose Coupling**: Components don't need to know about each other's implementation details. The metrics collector doesn't know about the correlation engine; it simply publishes its output to the event stream.

**Independent Scaling**: Each Lambda function scales independently based on its workload. If log collection becomes a bottleneck, only that function needs optimization.

**Asynchronous Processing**: The orchestrator doesn't wait for synchronous responses from collectors. It invokes them in parallel and aggregates results.

**Event Replay**: Failed workflows can be replayed by resubmitting the original alarm event to EventBridge.

**Event Flow:**
1. CloudWatch Alarm transitions to ALARM state
2. EventBridge captures the state change event
3. EventBridge rule matches the alarm pattern and routes to SNS topic
4. SNS topic triggers Step Functions orchestrator
5. Orchestrator emits events to invoke Lambda functions
6. Lambda functions publish results back to the orchestrator
7. Final results are published to DynamoDB and notification channels

This pattern mirrors production incident management systems like PagerDuty AIOps and Datadog Watchdog, where event-driven workflows enable real-time response to infrastructure changes.

### Parallel Fan-Out Pattern

The orchestrator uses a parallel fan-out pattern to minimize latency. Instead of collecting metrics, then logs, then deployment context sequentially (which would take 60+ seconds), all three collectors run simultaneously.

**Implementation**: Step Functions Parallel state invokes three Lambda functions concurrently. Each collector has its own timeout and retry policy. The orchestrator waits for all three to complete (or timeout) before proceeding to correlation.

**Benefits:**
- **Reduced Latency**: Total collection time is max(metrics_time, logs_time, changes_time) instead of sum
- **Independent Failure**: One collector failure doesn't block others
- **Resource Efficiency**: AWS Lambda scales each function independently

**Trade-off**: Parallel execution increases AWS Lambda concurrent execution count. For high-volume scenarios, this could hit account limits. However, for a portfolio project with low traffic, this is not a concern.

### Correlation Layer Pattern

A dedicated correlation engine sits between data collection and analysis. This layer normalizes heterogeneous data formats into a unified structure, simplifying downstream processing.

**Why a Separate Layer?**
- **Single Responsibility**: Each collector focuses on its data source; correlation focuses on normalization
- **Testability**: Correlation logic can be tested independently with mock collector outputs
- **Flexibility**: New collectors can be added without modifying the LLM analyzer
- **Size Management**: The correlation engine enforces the 50KB context size limit for LLM input

**Normalization Tasks:**
- Convert all timestamps to ISO 8601 UTC format
- Remove duplicate entries across data sources
- Sort events chronologically
- Calculate summary statistics (averages, error counts, change frequency)
- Truncate data if total size exceeds LLM context window

This pattern is common in data pipeline architectures where raw data from multiple sources needs transformation before consumption.

### Advisory-Only AI Pattern

The LLM analyzer generates root-cause hypotheses and recommendations but has **no permissions** to modify infrastructure. This is a critical security design decision.

**Why Advisory-Only?**
- **Safety**: Prevents AI hallucinations from causing infrastructure damage
- **Human Oversight**: Ensures experienced engineers review recommendations before action
- **Auditability**: All infrastructure changes have human accountability
- **Trust Building**: Operators gain confidence in AI recommendations over time

**Implementation**: The LLM analyzer's IAM role has explicit deny policies for all mutating AWS APIs (EC2, RDS, IAM, Lambda updates, etc.). Even if the LLM generates a recommendation to "terminate the instance," it cannot execute that action.

This pattern is used by production AI systems like GitHub Copilot (suggests code but doesn't commit) and AWS CodeGuru (recommends optimizations but doesn't deploy).

### Graceful Degradation Pattern

The system is designed to provide value even when components fail. This is critical for incident management systems that must remain operational during infrastructure issues.

**Failure Scenarios:**
- **Metrics Collector Fails**: Continue with logs and deployment context
- **Logs Collector Fails**: Continue with metrics and deployment context
- **Deploy Context Collector Fails**: Continue with metrics and logs
- **LLM Analyzer Fails**: Send notification with raw data and fallback message
- **Notification Service Fails**: Still persist incident to DynamoDB for later review

**Implementation**: Step Functions Catch blocks capture errors and pass them to the next state. The correlation engine checks which collectors succeeded and marks data completeness. The notification service attempts Slack and email independently.

**Trade-off**: Partial data may lead to less accurate LLM analysis. However, some analysis is better than no analysis, and the completeness indicator helps engineers understand data gaps.

## Technology Choices

### AWS Step Functions Express Workflows

**Choice**: Express Workflows instead of Standard Workflows

**Rationale:**
- **Cost**: Express Workflows are 5x cheaper ($1.00 per million requests vs $25.00 per million state transitions)
- **Latency**: Express Workflows have lower latency (< 5 minutes execution time)
- **Use Case Fit**: Incident analysis workflows are short-duration (< 2 minutes) and high-volume

**Trade-offs:**
- **No Execution History**: Express Workflows don't persist execution history beyond CloudWatch Logs
- **Limited Execution Time**: 5-minute maximum (vs 1 year for Standard)
- **No Manual Approval**: Can't pause for human input

For this use case, the trade-offs are acceptable. Incident analysis must complete quickly, and we persist results to DynamoDB for history. If we needed human approval steps or long-running workflows, Standard Workflows would be required.

### AWS Lambda with Python 3.11+

**Choice**: Lambda for compute, Python for language

**Rationale:**
- **Serverless**: No infrastructure management, automatic scaling, pay-per-use
- **Event Integration**: Native integration with Step Functions, EventBridge, SNS
- **Cold Start Optimization**: Python has faster cold starts than Java or .NET
- **AWS SDK**: boto3 provides comprehensive AWS API coverage
- **Data Processing**: Python excels at JSON manipulation and data transformation
- **LLM Integration**: Python is the de facto language for AI/ML workloads

**Trade-offs:**
- **Cold Starts**: Lambda functions experience cold start latency (100-500ms for Python)
- **Execution Time Limit**: 15-minute maximum (sufficient for our use case)
- **Memory Constraints**: Maximum 10GB memory (our functions use 256MB-1GB)

**Alternatives Considered:**
- **ECS/Fargate**: More control but requires container management and has higher baseline cost
- **EC2**: Full control but requires patching, scaling, and monitoring infrastructure
- **Node.js**: Faster cold starts but less mature AWS SDK and data processing libraries

Lambda with Python provides the best balance of cost, performance, and developer productivity for this use case.

### ARM64 Architecture (Graviton2)

**Choice**: ARM64 instead of x86_64

**Rationale:**
- **Cost**: 20% cheaper than x86_64 Lambda functions
- **Performance**: Graviton2 provides comparable or better performance for Python workloads
- **Sustainability**: ARM processors are more energy-efficient

**Trade-offs:**
- **Library Compatibility**: Some Python packages don't have ARM64 wheels (not an issue for our dependencies)
- **Local Testing**: Requires ARM64 Docker images or emulation

For a portfolio project focused on cost optimization, ARM64 is an easy win with minimal downside.

### Amazon Bedrock with Claude

**Choice**: Bedrock instead of self-hosted LLM or OpenAI API

**Rationale:**
- **Managed Service**: No infrastructure to manage, automatic scaling
- **AWS Integration**: Native IAM authentication, VPC support, CloudWatch logging
- **Data Privacy**: Data doesn't leave AWS, no third-party API calls
- **Claude Model**: Excellent at structured reasoning and following instructions
- **Cost**: Pay-per-token pricing with no minimum commitment

**Trade-offs:**
- **Model Selection**: Limited to AWS-supported models (Claude, Llama, Titan)
- **Latency**: Bedrock adds ~500ms overhead vs direct API calls
- **Cost**: More expensive than self-hosted models but cheaper than managing infrastructure

**Alternatives Considered:**
- **OpenAI API**: Better models but data leaves AWS, requires API key management
- **Self-Hosted LLM**: Full control but requires GPU instances, model management, and scaling
- **SageMaker**: More flexibility but higher complexity and cost

Bedrock provides the best balance of capability, security, and operational simplicity for a portfolio project.

### DynamoDB with On-Demand Billing

**Choice**: DynamoDB on-demand instead of provisioned capacity or RDS

**Rationale:**
- **Serverless**: No capacity planning, automatic scaling
- **Pay-Per-Use**: Only pay for actual read/write requests (ideal for portfolio project)
- **Low Latency**: Single-digit millisecond response times
- **TTL Support**: Automatic data expiration after 90 days
- **Global Secondary Indexes**: Efficient querying by resource ARN or severity

**Trade-offs:**
- **Cost at Scale**: On-demand is more expensive than provisioned at high volumes
- **Query Flexibility**: NoSQL requires careful index design vs SQL's ad-hoc queries
- **No Joins**: Must denormalize data or make multiple queries

**Alternatives Considered:**
- **RDS/Aurora**: Better for complex queries but requires capacity management and higher baseline cost
- **S3**: Cheaper storage but higher latency and no indexing
- **Provisioned DynamoDB**: Cheaper at scale but requires capacity planning

For a portfolio project with unpredictable traffic, on-demand billing eliminates the risk of over-provisioning while maintaining production-grade performance.

### EventBridge + SNS for Event Routing

**Choice**: EventBridge for pattern matching, SNS for fan-out

**Rationale:**
- **EventBridge**: Provides sophisticated event pattern matching (filter by alarm state, resource type, etc.)
- **SNS**: Provides reliable fan-out to multiple subscribers (Step Functions, future integrations)
- **Decoupling**: Alarm detection is decoupled from workflow orchestration
- **Extensibility**: New subscribers can be added without modifying alarm configuration

**Trade-offs:**
- **Complexity**: Two services instead of direct Lambda invocation
- **Latency**: Adds ~50-100ms to event routing
- **Cost**: Small additional cost for EventBridge rules and SNS messages

**Why Not Direct Integration?**
- CloudWatch Alarms → Lambda: Tightly couples alarm to specific function
- CloudWatch Alarms → Step Functions: No pattern matching or filtering
- EventBridge → Step Functions: No fan-out to multiple subscribers

The EventBridge + SNS pattern provides maximum flexibility for future enhancements (e.g., sending events to a data lake, triggering multiple workflows).

### Terraform for Infrastructure as Code

**Choice**: Terraform instead of CloudFormation or CDK

**Rationale:**
- **Multi-Cloud**: Terraform supports multiple cloud providers (demonstrates transferable skills)
- **State Management**: Explicit state files make infrastructure changes transparent
- **Module Ecosystem**: Large community with reusable modules
- **Plan/Apply Workflow**: Preview changes before applying (reduces errors)

**Trade-offs:**
- **AWS-Specific Features**: CloudFormation has better support for new AWS features
- **State Management**: Requires S3 backend configuration and state locking
- **Learning Curve**: HCL syntax vs native AWS tools

**Alternatives Considered:**
- **CloudFormation**: Native AWS support but verbose YAML and limited multi-cloud
- **CDK**: Type-safe infrastructure but requires TypeScript/Python knowledge and generates CloudFormation
- **Pulumi**: Modern IaC but smaller community and less mature

Terraform is the industry standard for IaC and demonstrates production-grade infrastructure management skills.

## Trade-offs and Design Decisions

### Express Workflows vs Standard Workflows

**Decision**: Use Express Workflows for orchestration

**Trade-offs:**

| Aspect | Express Workflows | Standard Workflows |
|--------|------------------|-------------------|
| Cost | $1.00 per million requests | $25.00 per million state transitions |
| Execution History | CloudWatch Logs only | Full history in Step Functions console |
| Max Duration | 5 minutes | 1 year |
| Execution Semantics | At-least-once | Exactly-once |
| Use Case | High-volume, short-duration | Long-running, human approval |

**Why Express?**
- Incident analysis must complete quickly (< 2 minutes)
- High volume of alarms in production environments
- Execution history persisted to DynamoDB anyway
- No human approval steps required

**When Standard Would Be Better:**
- Workflows requiring human approval (e.g., "Approve rollback?")
- Long-running processes (e.g., multi-day deployments)
- Need for exactly-once execution guarantees

### On-Demand vs Provisioned DynamoDB

**Decision**: Use on-demand billing mode

**Trade-offs:**

| Aspect | On-Demand | Provisioned |
|--------|-----------|-------------|
| Cost (low traffic) | Lower | Higher (pay for unused capacity) |
| Cost (high traffic) | Higher | Lower (bulk discount) |
| Capacity Planning | None required | Must predict traffic |
| Scaling | Instant | Gradual (4x per day) |
| Use Case | Unpredictable traffic | Steady, predictable traffic |

**Why On-Demand?**
- Portfolio project with unpredictable traffic
- No risk of throttling during demos
- Eliminates capacity planning complexity
- Total cost is negligible for demo purposes

**When Provisioned Would Be Better:**
- Production system with steady traffic patterns
- Cost optimization for high-volume workloads
- Predictable read/write patterns

### Parallel vs Sequential Data Collection

**Decision**: Collect metrics, logs, and deployment context in parallel

**Trade-offs:**

| Aspect | Parallel | Sequential |
|--------|----------|------------|
| Latency | ~20 seconds (max of all) | ~60 seconds (sum of all) |
| Complexity | Higher (error handling) | Lower (simple chain) |
| Resource Usage | 3x concurrent Lambda | 1x Lambda at a time |
| Failure Handling | Independent failures | One failure blocks all |

**Why Parallel?**
- Incident response requires speed (every second matters)
- AWS Lambda scales to handle concurrent executions
- Independent failure handling improves reliability
- Demonstrates production-grade architecture patterns

**When Sequential Would Be Better:**
- Strict ordering requirements (e.g., logs depend on metrics)
- Lambda concurrency limits are a concern
- Simpler error handling is preferred

### LLM Temperature: 0.3 vs 0.7 vs 1.0

**Decision**: Use temperature 0.3 for LLM analysis

**Trade-offs:**

| Temperature | Behavior | Use Case |
|-------------|----------|----------|
| 0.0 - 0.3 | Deterministic, focused | Factual analysis, structured output |
| 0.4 - 0.7 | Balanced creativity | General conversation, brainstorming |
| 0.8 - 1.0 | Creative, diverse | Creative writing, idea generation |

**Why 0.3?**
- Root-cause analysis requires factual, evidence-based reasoning
- Consistency is more important than creativity
- Structured output format (JSON) requires deterministic behavior
- Reduces hallucination risk

**When Higher Temperature Would Be Better:**
- Brainstorming potential solutions
- Generating diverse hypotheses
- Creative problem-solving scenarios

### 50KB Context Size Limit

**Decision**: Limit structured context to 50KB for LLM input

**Trade-offs:**

| Aspect | 50KB Limit | Unlimited |
|--------|-----------|-----------|
| LLM Cost | Lower (fewer tokens) | Higher (more tokens) |
| LLM Latency | Faster (less to process) | Slower (more to process) |
| Data Completeness | May truncate data | All data included |
| Context Window | Fits in Claude's window | May exceed limits |

**Why 50KB?**
- Claude's context window is 100K tokens (~400KB text)
- 50KB provides safety margin for prompt template and response
- Forces prioritization of recent, relevant data
- Reduces LLM cost and latency

**Truncation Strategy:**
- Keep all summary statistics (always small)
- Prioritize recent log entries and metrics
- Keep deployment changes (usually small)
- Truncate oldest data first

**When Larger Context Would Be Better:**
- Complex incidents requiring extensive historical data
- Models with larger context windows (e.g., Claude 3 with 200K tokens)
- Cost is not a constraint

### Secrets Manager vs Parameter Store for Secrets

**Decision**: Use Secrets Manager for Slack webhook, Parameter Store for prompt template

**Trade-offs:**

| Aspect | Secrets Manager | Parameter Store |
|--------|----------------|-----------------|
| Cost | $0.40/secret/month + API calls | Free (standard), $0.05/param (advanced) |
| Rotation | Automatic rotation support | Manual rotation |
| Encryption | Always encrypted | Optional encryption |
| Use Case | Credentials, API keys | Configuration, non-sensitive data |

**Why Both?**
- Secrets Manager for Slack webhook (credential, needs rotation)
- Parameter Store for prompt template (configuration, needs versioning)
- Demonstrates appropriate use of each service

**When to Use Secrets Manager:**
- Database passwords
- API keys and tokens
- Certificates and private keys

**When to Use Parameter Store:**
- Application configuration
- Feature flags
- Non-sensitive templates

### ARM64 vs x86_64 Lambda Architecture

**Decision**: Use ARM64 (Graviton2) for all Lambda functions

**Trade-offs:**

| Aspect | ARM64 | x86_64 |
|--------|-------|--------|
| Cost | 20% cheaper | Standard pricing |
| Performance | Comparable or better | Standard performance |
| Compatibility | Some packages lack ARM wheels | Universal compatibility |
| Local Testing | Requires ARM Docker or emulation | Native on most dev machines |

**Why ARM64?**
- 20% cost savings with no performance penalty
- All our dependencies (boto3, requests, hypothesis) support ARM64
- Demonstrates cost optimization awareness
- Industry trend toward ARM (AWS, Apple, etc.)

**When x86_64 Would Be Better:**
- Dependencies without ARM64 support
- Need for exact local/production parity
- Performance-critical workloads where x86_64 is faster

## Security Design

Security is a first-class concern in this system. Every component follows the principle of least privilege, and the LLM has explicit restrictions to prevent infrastructure modification.

### Least-Privilege IAM Roles

Each Lambda function has its own IAM role with only the permissions required for its specific task. This limits the blast radius if a function is compromised.

**Metrics Collector Role:**
- **Allowed**: `cloudwatch:GetMetricStatistics`, `cloudwatch:ListMetrics`
- **Denied**: None (no dangerous permissions to deny)
- **Rationale**: Only needs to read CloudWatch metrics, no write or mutate permissions

**Logs Collector Role:**
- **Allowed**: `logs:FilterLogEvents`, `logs:DescribeLogGroups`, `logs:DescribeLogStreams`
- **Denied**: None
- **Rationale**: Only needs to read CloudWatch Logs, no write or delete permissions

**Deploy Context Collector Role:**
- **Allowed**: `ssm:GetParameter`, `ssm:GetParameterHistory`, `cloudtrail:LookupEvents`
- **Denied**: None
- **Rationale**: Only needs to read configuration history and CloudTrail events

**Correlation Engine Role:**
- **Allowed**: Basic Lambda execution permissions only
- **Denied**: None
- **Rationale**: Pure data transformation, no AWS API calls required

**LLM Analyzer Role (MOST RESTRICTIVE):**
- **Allowed**: `bedrock:InvokeModel`, `ssm:GetParameter` (prompt template only)
- **Denied**: `ec2:*`, `rds:*`, `iam:*`, `s3:Delete*`, `dynamodb:Delete*`, `lambda:Update*`, `lambda:Delete*`
- **Rationale**: This is the AI component that could potentially be manipulated. Explicit denies prevent any infrastructure modification even if the LLM generates malicious recommendations.

**Notification Service Role:**
- **Allowed**: `secretsmanager:GetSecretValue`, `sns:Publish`
- **Denied**: None
- **Rationale**: Only needs to retrieve Slack webhook and publish to SNS topic

**Step Functions Orchestrator Role:**
- **Allowed**: `lambda:InvokeFunction` (specific functions only), `dynamodb:PutItem`, `xray:PutTraceSegments`
- **Denied**: None
- **Rationale**: Only needs to invoke workflow functions and store results

### Explicit Deny Policies for LLM

The LLM analyzer has explicit deny policies to prevent infrastructure modification. This is critical because:

1. **AI Hallucinations**: LLMs can generate plausible but incorrect recommendations
2. **Prompt Injection**: Malicious actors could craft incidents to manipulate LLM output
3. **Defense in Depth**: Even if IAM policies are misconfigured, explicit denies provide a safety net

**Denied Actions:**
- All EC2 operations (terminate instances, modify security groups)
- All RDS operations (delete databases, modify configurations)
- All IAM operations (create users, modify policies)
- All destructive S3 operations (delete buckets, delete objects)
- All destructive DynamoDB operations (delete tables, delete items)
- All Lambda mutation operations (update code, delete functions)

**Why Explicit Denies?**
- Deny policies override allow policies in AWS IAM
- Provides defense against accidental permission grants
- Makes security intent explicit in code

### Secrets Management

All secrets are stored in AWS Secrets Manager and retrieved at runtime. Secrets are never hardcoded in code, environment variables, or Terraform state files.

**Secrets Stored:**
- Slack webhook URL
- Email configuration (if using SMTP instead of SNS)

**Retrieval Pattern:**
```python
import boto3
import json

def get_slack_webhook():
    client = boto3.client('secretsmanager')
    response = client.get_secret_value(SecretId='incident-analysis/slack-webhook')
    return json.loads(response['SecretString'])['webhook_url']
```

**Security Benefits:**
- Secrets are encrypted at rest with KMS
- Access is logged in CloudTrail
- Secrets can be rotated without code changes
- IAM policies control who can retrieve secrets

### Data Encryption

All data is encrypted at rest and in transit:

**At Rest:**
- DynamoDB: Encrypted with AWS KMS customer-managed key
- CloudWatch Logs: Encrypted with CloudWatch Logs encryption
- Secrets Manager: Encrypted with KMS
- Parameter Store: Encrypted with KMS

**In Transit:**
- All AWS API calls use TLS 1.2+
- Slack webhook uses HTTPS
- SNS email uses TLS

### No PII in Logs

The system is designed to avoid logging personally identifiable information (PII):

- Resource ARNs are logged (not PII)
- Alarm names are logged (not PII)
- Metric values are logged (not PII)
- Log messages are logged (may contain PII, but filtered by log level)

**PII Handling:**
- If log messages contain PII, they are not sent to Slack (only stored in DynamoDB)
- Incident IDs are UUIDs (not sequential, no information leakage)
- Email addresses are stored in Secrets Manager (not logged)

### OIDC for CI/CD Authentication

The CI/CD pipeline uses OpenID Connect (OIDC) for AWS authentication instead of long-lived IAM access keys:

**Benefits:**
- No long-lived credentials to rotate or leak
- GitHub Actions authenticates directly with AWS
- Credentials are scoped to specific repositories and branches
- Automatic credential expiration after job completion

**Implementation:**
- GitHub OIDC provider configured in AWS IAM
- IAM role with trust policy for GitHub Actions
- Role assumed during workflow execution
- Credentials valid for job duration only

This is a production-grade security practice that eliminates the risk of leaked AWS credentials.

## Data Flow

This section describes the complete data flow from incident detection to notification.

### End-to-End Flow

```
1. CloudWatch Alarm → ALARM state
2. EventBridge captures state change
3. EventBridge rule matches pattern
4. SNS topic receives event
5. Step Functions orchestrator triggered
6. Parallel invocation:
   - Metrics Collector → CloudWatch Metrics API → Metrics JSON
   - Logs Collector → CloudWatch Logs API → Logs JSON
   - Deploy Context Collector → CloudTrail + SSM → Changes JSON
7. Correlation Engine merges data → Structured Context JSON
8. LLM Analyzer:
   - Retrieves prompt template from Parameter Store
   - Constructs prompt with Structured Context
   - Invokes Bedrock Claude model
   - Parses response → Analysis Report JSON
9. Parallel execution:
   - Notification Service:
     - Retrieves Slack webhook from Secrets Manager
     - Formats message
     - Sends to Slack and SNS email
   - DynamoDB:
     - Stores complete incident record
     - Sets TTL for 90-day expiration
10. Workflow completes
```

### Data Transformations

**Alarm Event → Incident Event:**
```json
// Input: CloudWatch Alarm Event
{
  "alarmName": "HighErrorRate",
  "alarmArn": "arn:aws:cloudwatch:...",
  "state": {"value": "ALARM"},
  "configuration": {
    "metrics": [{"name": "Errors", "namespace": "AWS/Lambda"}]
  }
}

// Output: Incident Event
{
  "incidentId": "550e8400-e29b-41d4-a716-446655440000",
  "alarmName": "HighErrorRate",
  "resourceArn": "arn:aws:lambda:us-east-1:123456789012:function:my-function",
  "timestamp": "2024-01-15T14:30:00Z",
  "alarmState": "ALARM",
  "metricName": "Errors",
  "namespace": "AWS/Lambda"
}
```

**Collector Outputs → Structured Context:**
```json
// Input: Three collector outputs
{
  "metrics": {
    "status": "success",
    "metrics": [{"metricName": "Errors", "datapoints": [...]}]
  },
  "logs": {
    "status": "success",
    "logs": [{"timestamp": "...", "message": "Connection timeout"}]
  },
  "changes": {
    "status": "success",
    "changes": [{"timestamp": "...", "eventName": "UpdateFunctionCode"}]
  }
}

// Output: Structured Context
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
    "topErrors": ["Connection timeout", "Memory exceeded"],
    "entries": [...]
  },
  "changes": {
    "recentDeployments": 1,
    "lastDeployment": "2024-01-15T14:23:00Z",
    "entries": [...]
  },
  "completeness": {
    "metrics": true,
    "logs": true,
    "changes": true
  }
}
```

**Structured Context → Analysis Report:**
```json
// Input: Structured Context (above)

// Output: Analysis Report
{
  "incidentId": "550e8400-e29b-41d4-a716-446655440000",
  "timestamp": "2024-01-15T14:31:00Z",
  "analysis": {
    "rootCauseHypothesis": "Lambda function experiencing connection timeouts to database after recent deployment",
    "confidence": "high",
    "evidence": [
      "Error rate increased from 2% to 15.5% at 14:25",
      "45 'Connection timeout' errors in logs starting at 14:25",
      "Function code updated at 14:23 (2 minutes before incident)"
    ],
    "contributingFactors": [
      "Recent deployment may have introduced connection pool misconfiguration",
      "Error rate spike correlates with deployment timing"
    ],
    "recommendedActions": [
      "Review connection pool settings in recent deployment",
      "Consider rollback to previous version",
      "Increase database connection timeout if appropriate"
    ]
  },
  "metadata": {
    "modelId": "anthropic.claude-v2",
    "modelVersion": "2.1",
    "promptVersion": "v1.0",
    "tokenUsage": {"input": 1500, "output": 300},
    "latency": 2.5
  }
}
```

**Analysis Report → Notification:**
```
🚨 Incident Alert: HighErrorRate

Resource: Lambda function `my-function`
Severity: High
Time: 2024-01-15 14:30:00 UTC

Root Cause Hypothesis (High Confidence):
Lambda function experiencing connection timeouts to database after recent deployment

Evidence:
• Error rate increased from 2% to 15.5% at 14:25
• 45 'Connection timeout' errors in logs starting at 14:25
• Function code updated at 14:23 (2 minutes before incident)

Recommended Actions:
1. Review connection pool settings in recent deployment
2. Consider rollback to previous version
3. Increase database connection timeout if appropriate

View Full Details: https://console.aws.amazon.com/dynamodb/incident/550e8400-...
```

### Data Size Management

The correlation engine enforces a 50KB limit on structured context to ensure it fits within the LLM's context window:

**Truncation Strategy:**
1. Calculate total size of merged data
2. If > 50KB, prioritize data:
   - Keep all summary statistics (small, high value)
   - Keep all deployment changes (usually small, high value)
   - Truncate metrics time series (keep recent 30 minutes)
   - Truncate log entries (keep most recent 50 entries)
3. Recalculate size and repeat if needed
4. Mark truncation in completeness indicator

This ensures the LLM always receives the most relevant, recent data even for high-volume incidents.

## Scalability and Performance

### Performance Targets

The system is designed to meet the following performance targets:

| Component | Target | Rationale |
|-----------|--------|-----------|
| End-to-End Workflow | < 120 seconds | Incident response requires speed |
| Metrics Collection | < 15 seconds | CloudWatch API is fast |
| Logs Collection | < 20 seconds | Log queries can be slow |
| Deploy Context Collection | < 15 seconds | CloudTrail queries are fast |
| Correlation | < 5 seconds | Pure data transformation |
| LLM Analysis | < 30 seconds | Bedrock latency + processing |
| Notification | < 10 seconds | Webhook + SNS are fast |

### Scalability Characteristics

**Horizontal Scaling:**
- Lambda functions scale automatically to 1000 concurrent executions (default limit)
- Each incident triggers 6 Lambda invocations (3 collectors + correlation + LLM + notification)
- System can handle ~166 concurrent incidents before hitting Lambda limits
- Limits can be increased via AWS support ticket

**Vertical Scaling:**
- Lambda memory can be increased up to 10GB if needed
- Current allocations (256MB-1GB) are sufficient for expected workloads
- DynamoDB scales automatically with on-demand billing

**Bottlenecks:**
- **Bedrock Rate Limits**: Claude model has rate limits (tokens per minute)
- **CloudWatch API Throttling**: High-volume metric/log queries may be throttled
- **Step Functions Execution Limit**: 1 million concurrent executions (unlikely to hit)

### Performance Optimizations

**Parallel Data Collection:**
- Reduces latency from 60s (sequential) to 20s (parallel)
- 3x improvement in data collection time

**ARM64 Architecture:**
- 20% cost savings with comparable performance
- Graviton2 processors are optimized for Python workloads

**Structured Logging:**
- JSON logs enable fast CloudWatch Insights queries
- Correlation IDs enable tracing across functions

**Context Size Limit:**
- 50KB limit reduces LLM token usage and latency
- Smaller prompts = faster responses and lower cost

**DynamoDB On-Demand:**
- No throttling during traffic spikes
- Instant scaling to handle load

### Cold Start Mitigation

Lambda cold starts can add 100-500ms latency. Mitigation strategies:

**Provisioned Concurrency (Not Used):**
- Keeps functions warm but adds cost
- Not cost-effective for portfolio project
- Would be appropriate for production with SLA requirements

**Lightweight Dependencies:**
- boto3 is included in Lambda runtime (no cold start penalty)
- requests library is small and fast to load
- Hypothesis is only used in tests (not deployed)

**ARM64 Architecture:**
- Graviton2 has faster cold starts than x86_64
- Python 3.11 has improved startup time

**Acceptable Trade-off:**
- Cold starts add ~200ms to first invocation
- Subsequent invocations are warm (< 10ms overhead)
- For incident response, 200ms is acceptable

### Load Testing Considerations

For production deployment, the system should be load tested:

**Test Scenarios:**
1. **Single Incident**: Verify end-to-end latency < 120s
2. **10 Concurrent Incidents**: Verify no throttling or failures
3. **100 Concurrent Incidents**: Identify bottlenecks and scaling limits
4. **Sustained Load**: 1 incident/second for 1 hour

**Monitoring During Load Tests:**
- Lambda concurrent executions
- Lambda throttles and errors
- DynamoDB consumed capacity
- Bedrock throttling errors
- Step Functions execution duration

**Expected Results:**
- System should handle 10 concurrent incidents with no degradation
- System should handle 100 concurrent incidents with graceful degradation (some Bedrock throttling)
- Bottleneck will be Bedrock rate limits, not Lambda or DynamoDB

## Cost Optimization

Cost optimization is a key design consideration for a portfolio project. The system is designed to minimize AWS costs while maintaining production-grade architecture.

### Cost Breakdown (Estimated Monthly)

**Assumptions:**
- 100 incidents per month (demo/portfolio usage)
- Average incident: 3 collectors + correlation + LLM + notification + storage
- Average LLM prompt: 2000 input tokens, 500 output tokens

| Service | Usage | Cost |
|---------|-------|------|
| Step Functions (Express) | 100 executions × 6 state transitions | $0.00 (free tier) |
| Lambda (ARM64) | 600 invocations × 1s × 512MB | $0.00 (free tier) |
| Bedrock (Claude) | 100 × (2000 input + 500 output tokens) | ~$0.30 |
| DynamoDB (On-Demand) | 100 writes + 100 reads | $0.00 (free tier) |
| CloudWatch Logs | 1GB logs × 7 days retention | $0.50 |
| Secrets Manager | 1 secret | $0.40 |
| Parameter Store | 1 parameter (standard) | $0.00 |
| EventBridge | 100 events | $0.00 (free tier) |
| SNS | 100 messages | $0.00 (free tier) |
| **Total** | | **~$1.20/month** |

**Cost Optimizations Applied:**

1. **Express Workflows**: 5x cheaper than Standard ($1 vs $25 per million)
2. **ARM64 Lambda**: 20% cheaper than x86_64
3. **On-Demand DynamoDB**: No cost for unused capacity
4. **7-Day Log Retention**: Reduces CloudWatch Logs storage cost
5. **Standard Parameter Store**: Free vs $0.05/month for advanced
6. **Free Tier Usage**: Most services stay within free tier at demo volumes

### Cost Scaling

**At Production Scale (10,000 incidents/month):**

| Service | Usage | Cost |
|---------|-------|------|
| Step Functions (Express) | 10K executions × 6 transitions | $0.06 |
| Lambda (ARM64) | 60K invocations × 1s × 512MB | $0.50 |
| Bedrock (Claude) | 10K × (2000 input + 500 output tokens) | ~$30.00 |
| DynamoDB (On-Demand) | 10K writes + 10K reads | $2.50 |
| CloudWatch Logs | 10GB logs × 7 days retention | $5.00 |
| Secrets Manager | 1 secret + 10K retrievals | $0.45 |
| **Total** | | **~$38.51/month** |

**Key Insight**: Bedrock (LLM) becomes the dominant cost at scale. This is expected and acceptable for AI-powered analysis.

### Cost Optimization Strategies

**For Portfolio Project:**
- Use free tier wherever possible
- Minimize log retention (7 days)
- Use on-demand billing (no unused capacity)
- Use ARM64 for 20% Lambda savings
- Use Express Workflows for 5x Step Functions savings

**For Production:**
- Consider provisioned DynamoDB if traffic is predictable
- Implement LLM response caching for similar incidents
- Use Reserved Capacity for Bedrock if available
- Increase log retention to 30+ days for compliance
- Consider Standard Workflows if execution history is required

**Cost Monitoring:**
- Tag all resources with "Project: AI-SRE-Portfolio"
- Use AWS Cost Explorer to track spending by tag
- Set up billing alerts for unexpected cost increases
- Monitor Bedrock token usage (primary cost driver)

### Cost vs Value Trade-offs

**Where We Spend:**
- Bedrock (LLM analysis): High value, worth the cost
- CloudWatch Logs: Essential for debugging, worth the cost
- Secrets Manager: Security best practice, worth the cost

**Where We Save:**
- Express Workflows: No execution history, but we store in DynamoDB
- Short log retention: 7 days sufficient for portfolio project
- On-demand billing: Pay only for what we use

**Not Worth Saving:**
- Removing LLM analysis (defeats the purpose)
- Removing graceful degradation (reduces reliability)
- Removing security features (bad practice)

## Observability

Observability is critical for understanding system behavior, debugging issues, and demonstrating production-grade practices.

### Structured Logging

All Lambda functions emit structured JSON logs to CloudWatch Logs:

```json
{
  "timestamp": "2024-01-15T14:30:00.123Z",
  "level": "INFO",
  "message": "Metrics collection completed",
  "correlationId": "550e8400-e29b-41d4-a716-446655440000",
  "component": "metrics-collector",
  "duration": 1.234,
  "metricsCount": 5,
  "resourceArn": "arn:aws:lambda:us-east-1:123456789012:function:my-function"
}
```

**Benefits:**
- **Queryable**: CloudWatch Insights can query JSON fields
- **Correlation**: All logs for an incident share the same correlationId
- **Debugging**: Structured data is easier to parse than free-form text
- **Alerting**: Can create alarms based on specific field values

**Log Levels:**
- **INFO**: Normal operation (function invoked, completed)
- **WARNING**: Recoverable errors (API throttling, retries)
- **ERROR**: Failures (collector failed, LLM timeout)
- **DEBUG**: Detailed information (not used in production)

### Correlation IDs

Every incident has a unique correlation ID (UUID v4) that flows through the entire workflow:

```
Alarm Event (incidentId: 550e8400-...)
  → Metrics Collector (correlationId: 550e8400-...)
  → Logs Collector (correlationId: 550e8400-...)
  → Deploy Context Collector (correlationId: 550e8400-...)
  → Correlation Engine (correlationId: 550e8400-...)
  → LLM Analyzer (correlationId: 550e8400-...)
  → Notification Service (correlationId: 550e8400-...)
```

**CloudWatch Insights Query:**
```
fields @timestamp, component, message, duration
| filter correlationId = "550e8400-e29b-41d4-a716-446655440000"
| sort @timestamp asc
```

This query shows the complete timeline of an incident across all components.

### Custom Metrics

The system emits custom CloudWatch metrics for monitoring:

**Workflow Metrics:**
- `IncidentAnalysis.WorkflowDuration` (milliseconds)
- `IncidentAnalysis.WorkflowSuccess` (count)
- `IncidentAnalysis.WorkflowFailure` (count)

**Collector Metrics:**
- `IncidentAnalysis.MetricsCollectorDuration` (milliseconds)
- `IncidentAnalysis.MetricsCollectorSuccess` (count)
- `IncidentAnalysis.MetricsCollectorFailure` (count)
- (Similar for logs and deploy context collectors)

**LLM Metrics:**
- `IncidentAnalysis.LLMLatency` (milliseconds)
- `IncidentAnalysis.LLMTokenUsage` (count)
- `IncidentAnalysis.LLMSuccess` (count)
- `IncidentAnalysis.LLMFailure` (count)

**Notification Metrics:**
- `IncidentAnalysis.NotificationDelivered` (count)
- `IncidentAnalysis.NotificationFailed` (count)

**Dimensions:**
- `Environment` (dev, staging, prod)
- `Component` (metrics-collector, llm-analyzer, etc.)

### CloudWatch Alarms

The system monitors itself with CloudWatch Alarms:

**Critical Alarms:**
- `WorkflowFailureRate > 10%` (5-minute period)
- `LLMFailureRate > 20%` (5-minute period)
- `NotificationFailureRate > 10%` (5-minute period)

**Warning Alarms:**
- `WorkflowDuration > 120 seconds` (p95)
- `LLMLatency > 30 seconds` (p95)
- `CollectorFailureRate > 5%` (any collector)

**Actions:**
- Send SNS notification to ops team
- Log to CloudWatch Logs
- (In production: trigger PagerDuty, create Jira ticket)

### X-Ray Tracing

Step Functions workflows are instrumented with AWS X-Ray for distributed tracing:

**Trace View:**
```
Step Functions Orchestrator (120s)
  ├─ Parallel Collection (20s)
  │  ├─ Metrics Collector (15s)
  │  ├─ Logs Collector (18s)
  │  └─ Deploy Context Collector (12s)
  ├─ Correlation Engine (3s)
  ├─ LLM Analyzer (25s)
  │  └─ Bedrock InvokeModel (24s)
  └─ Parallel Notification (5s)
     ├─ Notification Service (4s)
     │  ├─ Slack Webhook (2s)
     │  └─ SNS Publish (1s)
     └─ DynamoDB PutItem (2s)
```

**Benefits:**
- **Bottleneck Identification**: Quickly see which component is slow
- **Error Attribution**: See exactly where failures occur
- **Dependency Mapping**: Visualize service interactions

### Dashboards

CloudWatch Dashboard for system health:

**Widgets:**
1. **Workflow Success Rate** (line chart, 24 hours)
2. **Workflow Duration** (p50, p95, p99 line chart)
3. **Component Failure Rates** (stacked area chart)
4. **LLM Token Usage** (line chart, cost tracking)
5. **Notification Delivery Status** (pie chart)
6. **Recent Errors** (log insights query)

**Use Cases:**
- Daily health check
- Incident investigation
- Performance optimization
- Cost monitoring

### Log Retention

**Lambda Logs**: 7 days (cost optimization)
**Step Functions Logs**: 7 days
**Application Logs**: Stored in DynamoDB for 90 days (incident records)

**Rationale:**
- 7 days sufficient for debugging recent issues
- Long-term incident history in DynamoDB (structured, queryable)
- Reduces CloudWatch Logs storage cost

## Future Enhancements

This section describes potential enhancements for production deployment or portfolio expansion.

### Multi-Region Support

**Current State**: Single-region deployment

**Enhancement**: Deploy to multiple AWS regions for high availability

**Benefits:**
- Survive regional outages
- Reduce latency for global teams
- Demonstrate multi-region architecture skills

**Implementation:**
- Deploy infrastructure to multiple regions via Terraform workspaces
- Use Route 53 health checks for failover
- Replicate DynamoDB table with Global Tables
- Use EventBridge cross-region event routing

**Trade-offs:**
- Increased cost (2x-3x for multi-region)
- Increased complexity (cross-region replication, consistency)
- May be overkill for portfolio project

### Auto-Remediation

**Current State**: Advisory-only (no infrastructure modification)

**Enhancement**: Allow LLM to execute approved remediation actions

**Benefits:**
- Faster incident resolution
- Reduced manual toil
- Demonstrates advanced AI capabilities

**Implementation:**
- Define safe remediation actions (restart service, scale up, rollback)
- Require human approval for destructive actions
- Implement circuit breaker to prevent runaway automation
- Add comprehensive audit logging

**Trade-offs:**
- Significant security risk if misconfigured
- Requires extensive testing and validation
- May not be appropriate for portfolio project (demonstrates poor judgment)

**Recommendation**: Keep advisory-only for portfolio. Auto-remediation is controversial and requires extensive safety mechanisms.

### Incident Correlation

**Current State**: Each alarm is analyzed independently

**Enhancement**: Correlate related incidents across resources

**Benefits:**
- Identify cascading failures
- Reduce alert fatigue
- Provide better root-cause analysis

**Implementation:**
- Group incidents by time window (e.g., 5 minutes)
- Identify resource dependencies (e.g., Lambda → RDS)
- Analyze patterns across related incidents
- Generate single report for correlated incidents

**Trade-offs:**
- Increased complexity (dependency mapping, correlation logic)
- May delay notifications (waiting for correlation window)
- Requires resource dependency graph

**Recommendation**: Good enhancement for demonstrating advanced architecture skills.

### Historical Pattern Analysis

**Current State**: Each incident analyzed in isolation

**Enhancement**: Use historical incident data to improve analysis

**Benefits:**
- Identify recurring issues
- Improve confidence levels based on past incidents
- Suggest preventive actions

**Implementation:**
- Query DynamoDB for similar past incidents
- Include historical patterns in LLM prompt
- Track incident recurrence rate
- Generate trend reports

**Trade-offs:**
- Increased LLM token usage (larger prompts)
- Requires sufficient historical data
- May introduce bias from past incidents

**Recommendation**: Excellent enhancement for demonstrating data-driven decision making.

### Custom Alarm Integration

**Current State**: Only CloudWatch Alarms trigger workflows

**Enhancement**: Support custom alarm sources (Datadog, New Relic, PagerDuty)

**Benefits:**
- Broader applicability
- Demonstrates integration skills
- More realistic for multi-tool environments

**Implementation:**
- Add webhook endpoint (API Gateway + Lambda)
- Normalize external alarm formats to internal schema
- Support multiple alarm source types

**Trade-offs:**
- Increased complexity (multiple input formats)
- Security considerations (webhook authentication)
- May dilute focus of portfolio project

**Recommendation**: Good enhancement if targeting companies with multi-tool environments.

### Machine Learning for Anomaly Detection

**Current State**: Relies on CloudWatch Alarms for detection

**Enhancement**: Use ML to detect anomalies before alarms fire

**Benefits:**
- Proactive incident detection
- Reduce false positives
- Demonstrates ML skills

**Implementation:**
- Use CloudWatch Anomaly Detection or SageMaker
- Train models on historical metrics
- Trigger workflows on anomaly detection
- Compare ML predictions with alarm-based detection

**Trade-offs:**
- Significant complexity (model training, tuning, deployment)
- Requires historical data for training
- May be overkill for portfolio project

**Recommendation**: Only if targeting ML-focused roles. Otherwise, adds complexity without clear benefit.

### Slack Bot Integration

**Current State**: One-way notification to Slack

**Enhancement**: Interactive Slack bot for incident management

**Benefits:**
- Acknowledge incidents from Slack
- Request additional analysis
- Execute approved remediation actions
- Demonstrates chatbot/conversational AI skills

**Implementation:**
- Add Slack bot with slash commands
- Store incident state in DynamoDB
- Support commands: `/incident status`, `/incident analyze`, `/incident resolve`
- Use Slack interactive components for approvals

**Trade-offs:**
- Increased complexity (Slack API, state management)
- Requires Slack workspace for demo
- May distract from core architecture

**Recommendation**: Excellent enhancement for demonstrating full-stack skills and user experience focus.

### Cost Attribution

**Current State**: All costs tracked at project level

**Enhancement**: Attribute costs to specific teams/resources

**Benefits:**
- Chargeback to responsible teams
- Identify cost optimization opportunities
- Demonstrates FinOps skills

**Implementation:**
- Tag resources with team/owner
- Track Bedrock token usage per resource
- Generate cost reports by team
- Alert on cost anomalies

**Trade-offs:**
- Requires organizational context (teams, cost centers)
- May not be relevant for portfolio project
- Adds complexity without demonstrating core skills

**Recommendation**: Skip for portfolio. Focus on technical architecture over organizational concerns.

## Conclusion

This design document has explained the architecture patterns, technology choices, trade-offs, and security design for the AI-Assisted SRE Incident Analysis System. The system demonstrates production-grade practices while remaining cost-effective for a portfolio project.

**Key Takeaways:**

1. **Event-Driven Architecture**: Loose coupling enables independent scaling and deployment
2. **Parallel Fan-Out**: Minimizes latency by collecting data concurrently
3. **Advisory-Only AI**: Keeps humans in control while leveraging LLM capabilities
4. **Graceful Degradation**: Provides value even when components fail
5. **Security First**: Least-privilege IAM and explicit denies for LLM
6. **Cost Conscious**: Optimized for portfolio economics (~$1.20/month)
7. **Production Patterns**: Demonstrates real-world architecture skills

**Design Philosophy:**

The system prioritizes **demonstrating production-grade architecture patterns** over feature completeness. Every design decision balances cost, complexity, and learning value. The result is a system that showcases technical skills while remaining practical for portfolio purposes.

**For Interviewers:**

This design demonstrates understanding of:
- Event-driven serverless architecture
- AWS service selection and trade-offs
- Security best practices (least privilege, explicit denies)
- Cost optimization strategies
- Observability and monitoring
- Graceful degradation and error handling
- Infrastructure as Code with Terraform
- AI/ML integration with appropriate guardrails

The system is intentionally scoped to be implementable in a reasonable timeframe while showcasing a breadth of skills relevant to SRE and cloud architecture roles.
