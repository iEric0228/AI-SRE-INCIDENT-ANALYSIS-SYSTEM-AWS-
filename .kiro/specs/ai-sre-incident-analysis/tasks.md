# Implementation Plan: AI-Assisted SRE Incident Analysis System

## Overview

This implementation plan breaks down the AI-assisted incident analysis system into discrete coding tasks. The system will be built incrementally, starting with core infrastructure, then data collection components, followed by analysis and notification layers, and finally integration and testing.

The implementation uses Python 3.11+ for Lambda functions, Terraform for infrastructure, and follows AWS best practices for security and observability.

## Tasks

- [x] 0. Create test incident scenario infrastructure
  - [x] 0.1 Design test scenario architecture
    - Document test scenario in DEMO.md (EC2 high CPU alarm)
    - Define expected data flow (alarm → metrics → logs → deploy context → analysis)
    - Create architecture diagram for test scenario
    - Document success criteria (what makes a good test incident)
    - _Purpose: Establish concrete test case before building main system_
  
  - [x] 0.2 Create Terraform module for test infrastructure
    - Create `terraform/test-scenario/` directory
    - Define EC2 t2.micro instance with CloudWatch Agent
    - Define CloudWatch Alarm for CPU > 50% (1 minute, 1 evaluation period)
    - Define security group (SSH access for triggering load)
    - Define IAM role for CloudWatch Agent (metrics and logs)
    - Add outputs: instance ID, alarm ARN, log group name
    - Add README with setup and trigger instructions
    - _Purpose: Reproducible test infrastructure for development and demos_
  
  - [x] 0.3 Create alarm trigger utilities
    - Create `scripts/trigger-test-alarm.sh` to SSH and run CPU stress test
    - Create `scripts/capture-alarm-event.sh` to extract EventBridge event from CloudWatch Logs
    - Create `scripts/reset-test-alarm.sh` to return alarm to OK state
    - Document manual trigger steps in DEMO.md
    - _Purpose: Easy incident triggering during development_
  
  - [x] 0.4 Capture sample event payloads
    - Create `test-data/` directory
    - Deploy test infrastructure and trigger alarm
    - Capture `cloudwatch-alarm-event.json` from EventBridge
    - Manually query and save `sample-metrics.json` from CloudWatch API
    - Manually query and save `sample-logs.json` from CloudWatch Logs API
    - Manually query and save `sample-cloudtrail-events.json` from CloudTrail
    - Document data collection process in DEMO.md
    - _Purpose: Real AWS event schemas for unit test fixtures_
  
  - [x] 0.5 Create expected output samples
    - Create `test-data/expected-structured-context.json` (what correlation engine should produce)
    - Create `test-data/expected-analysis-report.json` (what LLM should generate)
    - Create `test-data/expected-slack-message.md` (what notification should look like)
    - Document reasoning for expected outputs in DEMO.md
    - _Purpose: Clear success criteria for each component_
  
  - [x] 0.6 Document test scenario in DEMO.md
    - Add "Test Scenario Overview" section
    - Add "How to Deploy Test Infrastructure" section
    - Add "How to Trigger Test Alarm" section
    - Add "Expected System Behavior" section with screenshots placeholders
    - Add "Troubleshooting Test Scenario" section
    - _Purpose: Complete documentation for reproducing test case_

- [x] 1. Set up project structure and development environment
  - Create directory structure for Lambda functions, Terraform modules, and tests
  - Set up Python virtual environment with dependencies (boto3, hypothesis, pytest, moto)
  - Configure pre-commit hooks for linting (black, flake8, mypy)
  - Create requirements.txt and requirements-dev.txt
  - Set up .gitignore for Python and Terraform
  - _Requirements: 13.1, 13.6_

- [x] 2. Define core data models and schemas
  - [x] 2.1 Create Python dataclasses for all data models
    - Implement IncidentEvent, MetricData, LogEntry, ChangeEvent classes
    - Implement StructuredContext, AnalysisReport, NotificationOutput classes
    - Add to_dict() and from_dict() methods for JSON serialization
    - Add validation methods for required fields
    - _Requirements: 1.3, 3.3, 4.4, 5.3, 6.1, 7.7, 8.4, 9.2_
  
  - [x] 2.2 Write property test for data model serialization
    - **Property: Serialization Round Trip**
    - **Validates: Requirements 6.1, 9.2**
    - For any data model instance, serializing to dict then deserializing must produce equivalent object
  
  - [x] 2.3 Write unit tests for data model validation
    - Test required field validation
    - Test invalid field types
    - Test edge cases (empty strings, None values)
    - _Requirements: 1.3, 6.1_

- [x] 3. Implement Metrics Collector Lambda
  - [x] 3.1 Create metrics collector function
    - Implement lambda_handler with structured logging
    - Implement CloudWatch Metrics API client wrapper
    - Implement resource ARN parsing to determine metric namespace
    - Implement time range calculation (-60min to +5min)
    - Implement metric data retrieval and normalization
    - Implement summary statistics calculation (avg, max, min, p95)
    - Add error handling for empty metrics and API failures
    - _Requirements: 3.1, 3.2, 3.3, 3.4_
  
  - [x] 3.2 Write property test for time range calculation
    - **Property 8: Time Range Calculation Correctness**
    - **Validates: Requirements 3.1**
    - For any timestamp, metrics time range must be exactly -60min to +5min
  
  - [x] 3.3 Write property test for output schema compliance
    - **Property 9: Collector Output Schema Compliance**
    - **Validates: Requirements 3.3**
    - For any collector output, JSON must contain status, metrics array, collection_duration
  
  - [x] 3.4 Write unit tests for metrics collector
    - Test successful metric retrieval
    - Test empty metrics handling
    - Test API throttling retry logic
    - Test resource ARN parsing for different AWS services
    - _Requirements: 3.1, 3.2, 3.3, 3.4_

- [x] 4. Implement Logs Collector Lambda
  - [x] 4.1 Create logs collector function
    - Implement lambda_handler with structured logging
    - Implement CloudWatch Logs API client wrapper
    - Implement resource ARN to log group name mapping
    - Implement time range calculation (-30min to +5min)
    - Implement log filtering for ERROR/WARN/CRITICAL levels
    - Implement result limiting (top 100 entries) and chronological sorting
    - Implement log data normalization
    - Add error handling for missing log groups and API failures
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5_
  
  - [x] 4.2 Write property test for log level filtering
    - **Property 10: Log Level Filtering**
    - **Validates: Requirements 4.2**
    - For any set of log entries, only ERROR/WARN/CRITICAL levels are returned
  
  - [x] 4.3 Write property test for log result limiting and ordering
    - **Property 11: Log Result Limiting and Ordering**
    - **Validates: Requirements 4.3**
    - For any log query with >100 entries, exactly 100 are returned in chronological order
  
  - [x] 4.4 Write unit tests for logs collector
    - Test successful log retrieval
    - Test log level filtering
    - Test result limiting
    - Test empty logs handling
    - Test log group name resolution
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5_

- [x] 5. Implement Deploy Context Collector Lambda
  - [x] 5.1 Create deploy context collector function
    - Implement lambda_handler with structured logging
    - Implement CloudTrail API client wrapper
    - Implement Systems Manager Parameter Store client wrapper
    - Implement time range calculation (-24h to incident time)
    - Implement CloudTrail event filtering for mutating operations
    - Implement change event classification (deployment/configuration/infrastructure)
    - Implement change data normalization
    - Add error handling for CloudTrail not enabled and API failures
    - _Requirements: 5.1, 5.2, 5.3, 5.4_
  
  - [x] 5.2 Write property test for change event classification
    - **Property 12: Change Event Classification**
    - **Validates: Requirements 5.2**
    - For any CloudTrail event, classification must be deployment, configuration, or infrastructure
  
  - [x] 5.3 Write unit tests for deploy context collector
    - Test CloudTrail event retrieval
    - Test Parameter Store change detection
    - Test change classification logic
    - Test empty changes handling
    - Test time range calculation
    - _Requirements: 5.1, 5.2, 5.3, 5.4_

- [x] 6. Checkpoint - Ensure collector tests pass
  - Run all collector unit tests and property tests
  - Verify test coverage meets 80% minimum
  - Ask the user if questions arise

- [x] 7. Implement Correlation Engine Lambda
  - [x] 7.1 Create correlation engine function
    - Implement lambda_handler with structured logging
    - Implement data merging from all three collectors
    - Implement completeness tracking for failed collectors
    - Implement timestamp normalization to ISO 8601 UTC
    - Implement duplicate removal and chronological sorting
    - Implement summary statistics calculation
    - Implement size constraint enforcement (50KB limit with truncation)
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.6_
  
  - [x] 7.2 Write property test for data correlation and merging
    - **Property 13: Data Correlation and Merging**
    - **Validates: Requirements 6.1**
    - For any set of collector outputs, merged context must contain all available data
  
  - [x] 7.3 Write property test for timestamp normalization
    - **Property 14: Timestamp Normalization**
    - **Validates: Requirements 6.2**
    - For any structured context, all timestamps must be ISO 8601 UTC format
  
  - [x] 7.4 Write property test for deduplication and sorting
    - **Property 15: Deduplication and Chronological Sorting**
    - **Validates: Requirements 6.3**
    - For any context with duplicates, output must have no duplicates and be chronologically sorted
  
  - [x] 7.5 Write property test for summary statistics
    - **Property 16: Summary Statistics Calculation**
    - **Validates: Requirements 6.4**
    - For any structured context, summary statistics must be correctly calculated
  
  - [x] 7.6 Write property test for context size constraint
    - **Property 17: Context Size Constraint**
    - **Validates: Requirements 6.6**
    - For any structured context, serialized size must not exceed 50KB
  
  - [x] 7.7 Write unit tests for correlation engine
    - Test merging with all collectors successful
    - Test merging with one collector failed
    - Test merging with multiple collectors failed
    - Test timestamp normalization edge cases
    - Test size truncation logic
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.6_

- [x] 8. Implement LLM Analyzer Lambda
  - [x] 8.1 Create LLM analyzer function
    - Implement lambda_handler with structured logging
    - Implement Bedrock client wrapper with retry logic
    - Implement Parameter Store client for prompt template retrieval
    - Implement prompt construction from structured context
    - Implement Bedrock invocation with Claude model (temperature 0.3)
    - Implement LLM response parsing into AnalysisReport
    - Implement fallback report generation on LLM failure
    - Implement metadata extraction (token usage, model version, latency)
    - Add circuit breaker pattern for Bedrock calls
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 7.7, 16.1_
  
  - [x] 8.2 Write property test for LLM prompt construction
    - **Property 18: LLM Prompt Construction**
    - **Validates: Requirements 7.1, 16.1**
    - For any structured context, prompt must include complete context and follow template format
  
  - [x] 8.3 Write property test for LLM response parsing
    - **Property 19: LLM Response Parsing**
    - **Validates: Requirements 7.4, 7.5**
    - For any LLM response (valid or malformed), output must be structured AnalysisReport or fallback
  
  - [x] 8.4 Write property test for analysis report metadata
    - **Property 20: Analysis Report Metadata Completeness**
    - **Validates: Requirements 7.7, 16.5**
    - For any analysis report, metadata must include model ID, version, prompt version, token usage, latency
  
  - [x] 8.5 Write unit tests for LLM analyzer
    - Test successful Bedrock invocation
    - Test LLM response parsing
    - Test fallback report on Bedrock failure
    - Test prompt template retrieval from Parameter Store
    - Test circuit breaker behavior
    - _Requirements: 7.1, 7.2, 7.4, 7.5, 7.7_

- [x] 9. Create prompt template in Parameter Store
  - Write structured prompt template with role definition, task description, input/output formats
  - Include instructions for confidence levels and evidence citation
  - Version the template (v1.0)
  - Store in AWS Systems Manager Parameter Store
  - _Requirements: 16.1, 16.2, 16.3, 16.4, 16.5_

- [x] 10. Implement Notification Service Lambda
  - [x] 10.1 Create notification service function
    - Implement lambda_handler with structured logging
    - Implement Secrets Manager client for webhook URL retrieval
    - Implement SNS client for email publishing
    - Implement Slack message formatting with blocks
    - Implement email message formatting (plain text + HTML)
    - Implement Slack webhook POST with retry logic
    - Implement SNS email publishing
    - Implement graceful degradation (continue on Slack failure)
    - Implement incident store link generation
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5, 8.6, 14.3_
  
  - [x] 10.2 Write property test for notification message completeness
    - **Property 21: Notification Message Completeness**
    - **Validates: Requirements 8.1, 8.4, 8.5**
    - For any analysis report, notification must include incident ID, resource, severity, hypothesis, actions, link
  
  - [x] 10.3 Write property test for notification graceful degradation
    - **Property 22: Notification Graceful Degradation**
    - **Validates: Requirements 8.6**
    - For any notification where Slack fails, email delivery must still be attempted
  
  - [x] 10.4 Write property test for secrets retrieval
    - **Property 29: Secrets Retrieval at Runtime**
    - **Validates: Requirements 14.3**
    - For any notification invocation, secrets must be retrieved from Secrets Manager at runtime
  
  - [x] 10.5 Write unit tests for notification service
    - Test Slack message formatting
    - Test email message formatting
    - Test Slack webhook delivery
    - Test SNS email publishing
    - Test graceful degradation on Slack failure
    - Test secrets retrieval
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5, 8.6_

- [x] 11. Checkpoint - Ensure all Lambda function tests pass
  - Run all unit tests and property tests for all Lambda functions
  - Verify test coverage meets 80% minimum
  - Verify all property tests run with 100 iterations
  - Ask the user if questions arise

- [x] 12. Define Terraform infrastructure modules
  - [x] 12.1 Create IAM roles and policies module
    - Define IAM role for each Lambda function with least-privilege permissions
    - Define IAM role for Step Functions orchestrator
    - Implement explicit deny policies for LLM analyzer (no EC2, RDS, IAM, mutating APIs)
    - Add CloudWatch Logs permissions for all roles
    - Add X-Ray permissions for orchestrator
    - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5, 10.6, 10.7_
  
  - [x] 12.2 Create Lambda functions module
    - Define Lambda function resources for all 6 functions
    - Configure ARM64 architecture (Graviton2)
    - Configure memory settings (256MB-1024MB based on function)
    - Configure timeout settings (10s-40s based on function)
    - Configure environment variables (region, table name, topic ARN)
    - Attach IAM roles to functions
    - Configure CloudWatch Logs retention (7 days)
    - _Requirements: 17.2, 17.3, 17.5_
  
  - [x] 12.3 Create DynamoDB table module
    - Define incident-analysis-store table with partition key (incidentId) and sort key (timestamp)
    - Define Global Secondary Index for resourceArn queries
    - Define Global Secondary Index for severity queries
    - Configure on-demand billing mode
    - Configure TTL attribute (ttl field, 90 days)
    - Configure encryption at rest with KMS
    - Configure point-in-time recovery
    - Add resource tags for cost tracking
    - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5, 17.4, 17.6_
  
  - [x] 12.4 Create Step Functions state machine module
    - Define Express Workflow state machine
    - Implement parallel data collection state with three branches
    - Implement correlation state
    - Implement LLM analysis state
    - Implement parallel notification and storage state
    - Configure retry policies (exponential backoff, 3 attempts)
    - Configure catch blocks for graceful degradation
    - Configure timeout (120 seconds)
    - Enable CloudWatch Logs and X-Ray tracing
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 17.1, 20.1, 20.2_
  
  - [x] 12.5 Create EventBridge and SNS module
    - Define EventBridge rule for CloudWatch Alarm state changes
    - Define event pattern filter for ALARM state
    - Define SNS topic for incident notifications
    - Define SNS subscription to trigger Step Functions
    - Configure dead-letter queue for failed events
    - _Requirements: 1.1, 1.2_
  
  - [x] 12.6 Create Secrets Manager module
    - Define secret for Slack webhook URL
    - Define secret for email configuration
    - Configure automatic rotation (90 days)
    - _Requirements: 14.1, 14.2_
  
  - [x] 12.7 Create CloudWatch alarms module
    - Define alarm for Step Functions workflow failures
    - Define alarm for LLM analyzer timeouts
    - Define alarm for notification delivery failures
    - Configure SNS topic for alarm notifications
    - _Requirements: 11.4_
  
  - [x] 12.8 Create Terraform variables and outputs
    - Define variables for region, environment, alarm thresholds, notification endpoints
    - Define outputs for orchestrator ARN, table name, SNS topic ARN
    - Add validation for required variables
    - _Requirements: 13.2, 13.3_
  
  - [x] 12.9 Create root Terraform configuration
    - Define provider configuration (AWS, version constraints)
    - Define backend configuration for state storage
    - Define module instantiations
    - Add resource tags (Project: AI-SRE-Portfolio, Environment)
    - Configure workspace support for multiple environments
    - _Requirements: 13.1, 13.4, 13.5_

- [x] 13. Write Terraform validation tests
  - Test IAM policies contain only allowed permissions
  - Test LLM analyzer has explicit deny for restricted services
  - Test all resources have required tags
  - Test DynamoDB TTL is configured correctly
  - Test Lambda functions use ARM64 architecture
  - Test Step Functions uses Express Workflow type
  - Test CloudWatch Logs retention is 7 days
  - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5, 17.1, 17.2, 17.3, 17.5_

- [x] 14. Implement event detection and routing logic
  - [x] 14.1 Create EventBridge event transformer
    - Implement Lambda function to transform CloudWatch Alarm events
    - Generate unique incident ID (UUID v4)
    - Extract alarm details and resource ARN
    - Normalize event structure
    - Publish to SNS topic
    - _Requirements: 1.1, 1.2, 1.3_
  
  - [x] 14.2 Write property test for event routing completeness
    - **Property 1: Event Routing Completeness**
    - **Validates: Requirements 1.1, 1.2, 1.3**
    - For any alarm event, resulting incident event must contain all required fields
  
  - [x] 14.3 Write property test for concurrent incident independence
    - **Property 2: Concurrent Incident Independence**
    - **Validates: Requirements 1.4**
    - For any set of simultaneous alarms, each must have unique incident ID
  
  - [x] 14.4 Write unit tests for event transformer
    - Test event transformation
    - Test incident ID generation
    - Test resource ARN extraction
    - Test SNS publishing
    - _Requirements: 1.1, 1.2, 1.3, 1.4_

- [x] 15. Implement orchestration observability
  - [x] 15.1 Add structured logging to all Lambda functions
    - Ensure all logs are valid JSON
    - Include correlation ID (incident ID) in all logs
    - Include function name, version, and timestamp
    - Include error details with stack traces on failures
    - _Requirements: 11.1, 11.2, 11.6_
  
  - [x] 15.2 Add custom CloudWatch metrics
    - Emit metric for workflow duration
    - Emit metrics for collector success rates
    - Emit metric for LLM invocation latency
    - Emit metric for notification delivery status
    - _Requirements: 11.3_
  
  - [x] 15.3 Write property test for structured logging
    - **Property 7: Structured Logging with Correlation IDs**
    - **Validates: Requirements 2.7, 11.1, 11.2**
    - For any incident workflow, all logs must be valid JSON with same correlation ID
  
  - [x] 15.4 Write property test for error logging
    - **Property 26: Error Logging with Stack Traces**
    - **Validates: Requirements 11.6**
    - For any component failure, error log must include message, stack trace, and context
  
  - [x] 15.5 Write unit tests for observability
    - Test log structure validation
    - Test correlation ID propagation
    - Test metric emission
    - Test error logging format
    - _Requirements: 11.1, 11.2, 11.3, 11.6_

- [x] 16. Implement graceful degradation properties
  - [x]* 16.1 Write property test for partial data handling
    - **Property 6: Graceful Degradation with Partial Data**
    - **Validates: Requirements 2.5, 12.1, 12.2, 12.3, 12.6**
    - For any workflow with collector failures, workflow must continue with available data
  
  - [x]* 16.2 Write property test for LLM failure notification
    - **Property 27: LLM Failure Notification**
    - **Validates: Requirements 12.4**
    - For any incident where LLM fails, notification must indicate analysis unavailable
  
  - [x]* 16.3 Write property test for storage despite notification failure
    - **Property 28: Storage Despite Notification Failure**
    - **Validates: Requirements 12.5**
    - For any incident where notification fails, incident must still be stored
  
  - [x]* 16.4 Write property test for retry exhaustion handling
    - **Property 30: Retry Exhaustion Handling**
    - **Validates: Requirements 20.4**
    - For any Lambda exhausting retries, orchestrator must mark data source unavailable and continue
  
  - [x]* 16.5 Write property test for error classification
    - **Property 31: Error Classification for Retries**
    - **Validates: Requirements 20.5**
    - For any error, system must correctly classify as retryable or non-retryable

- [x] 17. Implement DynamoDB storage operations
  - [x] 17.1 Add DynamoDB persistence to orchestrator
    - Implement PutItem operation in final state
    - Calculate TTL (90 days from incident timestamp)
    - Include all required fields in item
    - Add error handling for DynamoDB failures
    - _Requirements: 9.1, 9.2, 9.4_
  
  - [x]* 17.2 Write property test for incident persistence completeness
    - **Property 23: Incident Persistence Completeness**
    - **Validates: Requirements 9.1, 9.2**
    - For any completed incident, stored record must contain all required fields
  
  - [x]* 17.3 Write property test for incident query capability
    - **Property 24: Incident Query Capability**
    - **Validates: Requirements 9.3**
    - For any stored incident, it must be retrievable by resource ARN, time range, or severity
  
  - [x]* 17.4 Write property test for TTL configuration
    - **Property 25: TTL Configuration Correctness**
    - **Validates: Requirements 9.4**
    - For any stored incident, TTL must be exactly 90 days from incident timestamp
  
  - [x]* 17.5 Write unit tests for DynamoDB operations
    - Test successful item persistence
    - Test TTL calculation
    - Test query by resource ARN
    - Test query by severity
    - Test query by time range
    - _Requirements: 9.1, 9.2, 9.3, 9.4_

- [x] 18. Checkpoint - Ensure all property tests pass
  - Run all property tests with 100 iterations
  - Verify all 31 properties pass
  - Review any failing properties and fix issues
  - Ask the user if questions arise

- [x] 19. Write integration tests
  - [x]* 19.1 Write end-to-end workflow integration test
    - Test complete workflow from alarm to notification with mocked AWS services
    - Verify all components are invoked in correct order
    - Verify incident is stored in DynamoDB
    - Verify notification is sent
    - _Requirements: 2.1, 2.2, 2.3, 2.4_
  
  - [x]* 19.2 Write partial failure integration tests
    - Test workflow with metrics collector failure
    - Test workflow with logs collector failure
    - Test workflow with deploy context collector failure
    - Test workflow with LLM analyzer failure
    - Test workflow with notification service failure
    - Verify graceful degradation in each case
    - _Requirements: 2.5, 12.1, 12.2, 12.3, 12.4, 12.5_
  
  - [x]* 19.3 Write performance integration test
    - Test workflow completes within 120 seconds
    - Test individual collector timeouts
    - Test LLM analyzer timeout
    - _Requirements: 2.6, 3.5, 4.6, 5.5, 7.6_

- [x] 20. Set up GitHub Actions CI/CD pipeline
  - [x] 20.1 Create GitHub Actions workflow file
    - Configure OIDC authentication for AWS
    - Add job for Terraform validation and linting
    - Add job for Python linting (black, flake8, mypy)
    - Add job for unit tests with coverage report
    - Add job for property tests (20 iterations on PR, 100 on merge)
    - Add job for integration tests against dev environment
    - Add job for Terraform plan on PR
    - Add job for Terraform apply on merge to main (dev environment)
    - Add manual approval gate for production deployment
    - Add deployment summary generation
    - _Requirements: 15.1, 15.2, 15.3, 15.4, 15.5, 15.6_
  
  - [x] 20.2 Configure AWS OIDC provider
    - Create OIDC identity provider in AWS
    - Create IAM role for GitHub Actions with trust policy
    - Grant permissions for Terraform operations
    - _Requirements: 15.1_
  
  - [x] 20.3 Test CI/CD pipeline
    - Create test PR and verify all checks pass
    - Merge to main and verify dev deployment
    - Verify deployment summary is generated
    - _Requirements: 15.2, 15.3, 15.6_

- [x] 21. Create documentation
  - [x] 21.1 Write README.md
    - Add architecture diagram (Mermaid)
    - Add setup instructions (prerequisites, AWS account setup, Terraform init/apply)
    - Add usage examples (triggering test alarms, viewing incidents)
    - Add troubleshooting section
    - Add cost estimation
    - _Requirements: 19.1_
  
  - [x] 21.2 Write DESIGN.md
    - Explain architecture patterns (event-driven, parallel fan-out, correlation layer)
    - Explain technology choices (Step Functions, Lambda, Bedrock, DynamoDB)
    - Explain trade-offs (Express vs Standard workflows, on-demand vs provisioned DynamoDB)
    - Explain security design (least-privilege IAM, LLM restrictions)
    - _Requirements: 19.3, 19.5_
  
  - [x] 21.3 Write DEMO.md
    - Create sample incident scenarios
    - Add expected outputs for each scenario
    - Add screenshots of Slack notifications
    - Add screenshots of DynamoDB incident records
    - Add screenshots of CloudWatch dashboards
    - _Requirements: 19.4_
  
  - [x] 21.4 Add inline code comments
    - Document complex algorithms (correlation, size truncation)
    - Document error handling strategies
    - Document retry logic
    - _Requirements: 19.2_

- [x] 22. Deploy to dev environment and validate
  - Run Terraform apply to create all infrastructure
  - Verify all resources are created with correct tags
  - Create test CloudWatch Alarm
  - Trigger alarm and verify end-to-end workflow
  - Verify incident appears in DynamoDB
  - Verify notification is sent to Slack
  - Verify CloudWatch Logs contain structured logs
  - Verify CloudWatch Metrics are emitted
  - _Requirements: 13.5, 17.6_

- [x] 23. Final checkpoint - System validation
  - Run complete test suite (unit, property, integration)
  - Verify test coverage meets 80% minimum
  - Verify all 31 correctness properties pass
  - Verify Terraform validation passes
  - Verify CI/CD pipeline passes
  - Verify documentation is complete
  - Ask the user if questions arise

## Notes

- Tasks marked with `*` are optional test tasks and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Property tests validate universal correctness properties (31 total)
- Unit tests validate specific examples and edge cases
- Integration tests validate end-to-end workflows
- Checkpoints ensure incremental validation
- All Lambda functions use Python 3.11+ with boto3
- All infrastructure uses Terraform with modular structure
- CI/CD uses GitHub Actions with OIDC (no long-lived credentials)
- System follows AWS best practices for security, observability, and cost optimization
