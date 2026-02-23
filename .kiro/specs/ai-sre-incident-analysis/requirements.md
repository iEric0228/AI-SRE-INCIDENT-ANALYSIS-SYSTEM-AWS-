# Requirements Document: AI-Assisted SRE Incident Analysis System

## Introduction

This document specifies requirements for an AI-assisted incident analysis pipeline on AWS that detects infrastructure issues, orchestrates parallel data collection, analyzes incidents using LLM reasoning, and notifies humans with actionable insights. The system is advisory-only (no auto-remediation), secure by default, and demonstrates production-grade event-driven architecture patterns for portfolio/interview purposes.

## Glossary

- **Incident_Detection_System**: The CloudWatch Alarms and EventBridge rules that detect infrastructure anomalies
- **Orchestrator**: The AWS Step Functions state machine that coordinates the incident analysis workflow
- **Metrics_Collector**: Lambda function that retrieves CloudWatch metrics for the affected resource
- **Logs_Collector**: Lambda function that retrieves CloudWatch Logs for the affected resource
- **Deploy_Context_Collector**: Lambda function that retrieves recent deployment history and configuration changes
- **Correlation_Engine**: Lambda function that merges and normalizes data from all collectors
- **LLM_Analyzer**: Lambda function that invokes Amazon Bedrock to generate root-cause hypotheses
- **Notification_Service**: Lambda function that sends structured incident reports to Slack/Email
- **Incident_Store**: DynamoDB table that persists incident history and analysis results
- **Valid_Incident_Event**: An event containing alarm name, resource ARN, timestamp, and alarm state
- **Structured_Context**: Normalized JSON containing metrics, logs, and deployment data
- **Analysis_Report**: LLM-generated document containing root-cause hypothesis, evidence, and recommendations

## Requirements

### Requirement 1: Incident Detection and Event Routing

**User Story:** As an SRE, I want the system to automatically detect infrastructure issues via CloudWatch Alarms, so that incidents are captured without manual monitoring.

#### Acceptance Criteria

1. WHEN a CloudWatch Alarm transitions to ALARM state, THE Incident_Detection_System SHALL publish an event to EventBridge
2. WHEN an EventBridge event matches the incident pattern, THE Incident_Detection_System SHALL trigger the Orchestrator via SNS
3. THE Incident_Detection_System SHALL include alarm name, resource ARN, timestamp, and alarm state in the event payload
4. WHEN multiple alarms fire simultaneously, THE Incident_Detection_System SHALL process each alarm as a separate incident
5. IF an alarm transitions to OK state within 30 seconds of ALARM state, THEN THE Incident_Detection_System SHALL cancel the incident workflow

### Requirement 2: Workflow Orchestration

**User Story:** As a system architect, I want a central orchestrator to coordinate parallel data collection and sequential analysis, so that the system is maintainable and observable.

#### Acceptance Criteria

1. WHEN the Orchestrator receives a Valid_Incident_Event, THE Orchestrator SHALL invoke Metrics_Collector, Logs_Collector, and Deploy_Context_Collector in parallel
2. WHEN all three collectors complete successfully, THE Orchestrator SHALL invoke the Correlation_Engine
3. WHEN the Correlation_Engine completes, THE Orchestrator SHALL invoke the LLM_Analyzer
4. WHEN the LLM_Analyzer completes, THE Orchestrator SHALL invoke the Notification_Service and store results in Incident_Store in parallel
5. IF any collector fails, THEN THE Orchestrator SHALL continue with available data and mark the incident as partial
6. THE Orchestrator SHALL complete the entire workflow within 120 seconds
7. THE Orchestrator SHALL emit structured logs at each state transition

### Requirement 3: Metrics Collection

**User Story:** As an incident analyst, I want to retrieve relevant CloudWatch metrics for the affected resource, so that I can understand performance trends leading to the incident.

#### Acceptance Criteria

1. WHEN the Metrics_Collector receives a resource ARN and timestamp, THE Metrics_Collector SHALL query CloudWatch for metrics from 60 minutes before to 5 minutes after the incident
2. THE Metrics_Collector SHALL retrieve CPU utilization, memory utilization, network traffic, and error rates where applicable
3. THE Metrics_Collector SHALL return metrics in a normalized JSON structure with timestamps, metric names, and values
4. IF no metrics are available for the resource, THEN THE Metrics_Collector SHALL return an empty metrics array and log a warning
5. THE Metrics_Collector SHALL complete within 15 seconds

### Requirement 4: Logs Collection

**User Story:** As an incident analyst, I want to retrieve relevant CloudWatch Logs for the affected resource, so that I can identify error messages and anomalies.

#### Acceptance Criteria

1. WHEN the Logs_Collector receives a resource ARN and timestamp, THE Logs_Collector SHALL query CloudWatch Logs for entries from 30 minutes before to 5 minutes after the incident
2. THE Logs_Collector SHALL filter for ERROR, WARN, and CRITICAL level messages
3. THE Logs_Collector SHALL return up to 100 most relevant log entries in chronological order
4. THE Logs_Collector SHALL return logs in a normalized JSON structure with timestamps, log levels, and messages
5. IF no logs are available for the resource, THEN THE Logs_Collector SHALL return an empty logs array and log a warning
6. THE Logs_Collector SHALL complete within 20 seconds

### Requirement 5: Deployment Context Collection

**User Story:** As an incident analyst, I want to know about recent deployments and configuration changes, so that I can correlate incidents with change events.

#### Acceptance Criteria

1. WHEN the Deploy_Context_Collector receives a resource ARN and timestamp, THE Deploy_Context_Collector SHALL query AWS Systems Manager Parameter Store and CloudTrail for changes in the past 24 hours
2. THE Deploy_Context_Collector SHALL identify deployments, configuration updates, and infrastructure changes
3. THE Deploy_Context_Collector SHALL return changes in a normalized JSON structure with timestamps, change types, and descriptions
4. IF no changes are found, THEN THE Deploy_Context_Collector SHALL return an empty changes array
5. THE Deploy_Context_Collector SHALL complete within 15 seconds

### Requirement 6: Data Correlation and Normalization

**User Story:** As a system designer, I want collected data to be merged and normalized, so that the LLM receives clean, structured input.

#### Acceptance Criteria

1. WHEN the Correlation_Engine receives outputs from all collectors, THE Correlation_Engine SHALL merge them into a single Structured_Context object
2. THE Correlation_Engine SHALL normalize timestamps to ISO 8601 format
3. THE Correlation_Engine SHALL remove duplicate entries and sort events chronologically
4. THE Correlation_Engine SHALL calculate summary statistics (metric averages, log error counts, change frequency)
5. THE Correlation_Engine SHALL complete within 5 seconds
6. THE Structured_Context SHALL not exceed 50KB in size

### Requirement 7: LLM-Based Root Cause Analysis

**User Story:** As an SRE, I want the system to generate root-cause hypotheses using AI reasoning, so that I can quickly understand complex incidents.

#### Acceptance Criteria

1. WHEN the LLM_Analyzer receives Structured_Context, THE LLM_Analyzer SHALL construct a structured prompt for Amazon Bedrock
2. THE LLM_Analyzer SHALL invoke Bedrock with the Claude model and a temperature of 0.3
3. THE LLM_Analyzer SHALL request the LLM to provide: root-cause hypothesis, supporting evidence, confidence level, and recommended actions
4. THE LLM_Analyzer SHALL parse the LLM response into a structured Analysis_Report
5. IF the LLM invocation fails, THEN THE LLM_Analyzer SHALL return a fallback report indicating analysis unavailable
6. THE LLM_Analyzer SHALL complete within 30 seconds
7. THE LLM_Analyzer SHALL include token usage and model version in the Analysis_Report metadata

### Requirement 8: Incident Notification

**User Story:** As an on-call engineer, I want to receive structured incident reports via Slack and email, so that I can respond quickly with full context.

#### Acceptance Criteria

1. WHEN the Notification_Service receives an Analysis_Report, THE Notification_Service SHALL format it as a human-readable message
2. THE Notification_Service SHALL send the message to a configured Slack channel via webhook
3. THE Notification_Service SHALL send the message to a configured email distribution list via SNS
4. THE notification SHALL include: incident ID, affected resource, severity, root-cause hypothesis, and recommended actions
5. THE notification SHALL include a link to the full incident details in the Incident_Store
6. IF Slack delivery fails, THEN THE Notification_Service SHALL still attempt email delivery
7. THE Notification_Service SHALL complete within 10 seconds

### Requirement 9: Incident History Storage

**User Story:** As an SRE manager, I want all incidents and analyses to be stored persistently, so that I can review historical patterns and improve systems.

#### Acceptance Criteria

1. WHEN an incident analysis completes, THE Incident_Store SHALL persist the complete incident record
2. THE Incident_Store SHALL store: incident ID, timestamp, resource ARN, alarm details, Structured_Context, Analysis_Report, and notification status
3. THE Incident_Store SHALL support querying incidents by resource ARN, time range, and severity
4. THE Incident_Store SHALL retain incidents for 90 days
5. THE Incident_Store SHALL encrypt all data at rest using AWS KMS

### Requirement 10: Security and Least Privilege

**User Story:** As a security engineer, I want each component to have minimal IAM permissions, so that the system follows the principle of least privilege.

#### Acceptance Criteria

1. THE Metrics_Collector SHALL have IAM permissions ONLY for cloudwatch:GetMetricStatistics and cloudwatch:ListMetrics
2. THE Logs_Collector SHALL have IAM permissions ONLY for logs:FilterLogEvents and logs:DescribeLogGroups
3. THE Deploy_Context_Collector SHALL have IAM permissions ONLY for ssm:GetParameter, ssm:GetParameterHistory, and cloudtrail:LookupEvents with read-only scope
4. THE LLM_Analyzer SHALL have IAM permissions ONLY for bedrock:InvokeModel
5. THE LLM_Analyzer SHALL NOT have permissions for any EC2, RDS, IAM, or mutating AWS APIs
6. THE Notification_Service SHALL have IAM permissions ONLY for sns:Publish and secretsmanager:GetSecretValue
7. THE Orchestrator SHALL have IAM permissions ONLY to invoke the specific Lambda functions in the workflow
8. WHEN any component attempts an unauthorized action, THE component SHALL fail with an access denied error and log the attempt

### Requirement 11: Observability and Monitoring

**User Story:** As an SRE, I want comprehensive logging and metrics for the incident analysis system itself, so that I can troubleshoot and optimize it.

#### Acceptance Criteria

1. THE system SHALL emit structured JSON logs to CloudWatch Logs for all Lambda functions
2. THE system SHALL include correlation IDs in all logs for a single incident workflow
3. THE system SHALL emit custom CloudWatch metrics for: workflow duration, collector success rates, LLM invocation latency, and notification delivery status
4. THE system SHALL create CloudWatch Alarms for: workflow failures, LLM timeout, and notification delivery failures
5. THE Orchestrator SHALL emit X-Ray traces for the complete workflow
6. WHEN a component fails, THE system SHALL log the error with stack trace and context

### Requirement 12: Graceful Degradation

**User Story:** As a system architect, I want the system to handle partial failures gracefully, so that one failing component doesn't block the entire analysis.

#### Acceptance Criteria

1. IF the Metrics_Collector fails, THEN THE Orchestrator SHALL continue with logs and deployment context
2. IF the Logs_Collector fails, THEN THE Orchestrator SHALL continue with metrics and deployment context
3. IF the Deploy_Context_Collector fails, THEN THE Orchestrator SHALL continue with metrics and logs
4. IF the LLM_Analyzer fails, THEN THE Notification_Service SHALL send a notification indicating analysis unavailable
5. IF the Notification_Service fails, THEN THE Incident_Store SHALL still persist the incident record
6. THE Analysis_Report SHALL include a completeness indicator showing which data sources were available

### Requirement 13: Infrastructure as Code

**User Story:** As a DevOps engineer, I want all infrastructure defined in Terraform, so that the system is reproducible and version-controlled.

#### Acceptance Criteria

1. THE system SHALL define all AWS resources using Terraform modules
2. THE Terraform configuration SHALL use variables for environment-specific values (region, alarm thresholds, notification endpoints)
3. THE Terraform configuration SHALL output the Orchestrator ARN, Incident_Store table name, and SNS topic ARN
4. THE Terraform configuration SHALL support multiple environments (dev, staging, prod) via workspaces or separate state files
5. WHEN Terraform is applied, THE system SHALL create all resources with appropriate tags for cost tracking
6. THE Terraform configuration SHALL include a README with setup instructions

### Requirement 14: Secrets Management

**User Story:** As a security engineer, I want all secrets stored securely in AWS Secrets Manager, so that credentials are never hardcoded.

#### Acceptance Criteria

1. THE system SHALL store Slack webhook URLs in AWS Secrets Manager
2. THE system SHALL store email configuration in AWS Secrets Manager
3. THE Notification_Service SHALL retrieve secrets at runtime using the AWS SDK
4. THE system SHALL NOT include any secrets in Terraform state files or Lambda environment variables
5. THE system SHALL rotate secrets automatically every 90 days

### Requirement 15: CI/CD Integration

**User Story:** As a developer, I want automated deployment via GitHub Actions, so that changes are tested and deployed consistently.

#### Acceptance Criteria

1. THE system SHALL use GitHub Actions with OIDC for AWS authentication (no long-lived credentials)
2. THE CI/CD pipeline SHALL run Terraform validation and linting on pull requests
3. THE CI/CD pipeline SHALL run unit tests for all Lambda functions
4. THE CI/CD pipeline SHALL deploy to a dev environment on merge to main branch
5. THE CI/CD pipeline SHALL require manual approval for production deployments
6. THE CI/CD pipeline SHALL create a deployment summary with resource changes

### Requirement 16: LLM Prompt Engineering

**User Story:** As an AI engineer, I want the LLM prompt to be structured and versioned, so that analysis quality is consistent and improvable.

#### Acceptance Criteria

1. THE LLM_Analyzer SHALL use a prompt template stored in AWS Systems Manager Parameter Store
2. THE prompt template SHALL include: role definition, task description, input format, output format, and constraints
3. THE prompt template SHALL instruct the LLM to provide confidence levels (high, medium, low) for hypotheses
4. THE prompt template SHALL instruct the LLM to cite specific evidence from the Structured_Context
5. THE prompt template SHALL be versioned and the version SHALL be included in the Analysis_Report metadata
6. WHEN the prompt template is updated, THE LLM_Analyzer SHALL use the new version without code changes

### Requirement 17: Cost Optimization

**User Story:** As a project owner, I want the system to minimize AWS costs, so that it remains affordable for a portfolio project.

#### Acceptance Criteria

1. THE Orchestrator SHALL use Express Workflows (not Standard Workflows) to reduce Step Functions costs
2. THE Lambda functions SHALL use ARM64 architecture (Graviton2) for cost efficiency
3. THE Lambda functions SHALL have memory configured to minimize cost while meeting performance requirements
4. THE Incident_Store SHALL use on-demand billing mode for DynamoDB
5. THE system SHALL use CloudWatch Logs retention of 7 days for Lambda logs
6. THE system SHALL tag all resources with "Project: AI-SRE-Portfolio" for cost tracking

### Requirement 18: Testing and Validation

**User Story:** As a developer, I want comprehensive tests for all components, so that I can validate correctness and prevent regressions.

#### Acceptance Criteria

1. THE system SHALL include unit tests for all Lambda function handlers
2. THE system SHALL include integration tests that validate the complete workflow using mocked AWS services
3. THE system SHALL include property-based tests for the Correlation_Engine to validate data normalization
4. THE system SHALL include tests for IAM permission boundaries
5. THE system SHALL achieve minimum 80% code coverage
6. THE tests SHALL run in CI/CD pipeline before deployment

### Requirement 19: Documentation

**User Story:** As an interviewer, I want clear documentation explaining the system architecture and design decisions, so that I can evaluate the candidate's understanding.

#### Acceptance Criteria

1. THE system SHALL include a README with: architecture diagram, setup instructions, and usage examples
2. THE system SHALL include inline code comments explaining complex logic
3. THE system SHALL include a DESIGN.md document explaining: architecture patterns, technology choices, and trade-offs
4. THE system SHALL include a DEMO.md document with: sample incidents, expected outputs, and screenshots
5. THE documentation SHALL explain why this architecture was chosen over alternatives

### Requirement 20: Error Handling and Retries

**User Story:** As an SRE, I want the system to handle transient failures with retries, so that temporary AWS API issues don't cause incident analysis to fail.

#### Acceptance Criteria

1. THE Orchestrator SHALL configure retry policies for all Lambda invocations with exponential backoff
2. THE Orchestrator SHALL retry failed Lambda invocations up to 3 times
3. THE Lambda functions SHALL use the AWS SDK's built-in retry logic for API calls
4. IF a Lambda function exhausts all retries, THEN THE Orchestrator SHALL mark that data source as unavailable and continue
5. THE system SHALL distinguish between retryable errors (throttling, timeouts) and non-retryable errors (invalid input, permission denied)
