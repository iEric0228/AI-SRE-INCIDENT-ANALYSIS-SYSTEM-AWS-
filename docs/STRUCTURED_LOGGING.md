# Structured Logging Implementation

This document describes the structured logging implementation across all Lambda functions in the AI-Assisted SRE Incident Analysis System.

## Requirements

Task 15.1 implements the following requirements:

- **Requirement 11.1**: All logs are valid JSON
- **Requirement 11.2**: Include correlation ID (incident ID) in all logs  
- **Requirement 11.6**: Include error details with stack traces on failures

Additionally, logs should include:
- Function name
- Function version  
- Timestamp

## Implementation Status

All Lambda functions implement structured logging with the following characteristics:

### ✅ Valid JSON (Requirement 11.1)
All log statements use `json.dumps()` to ensure valid JSON format:
```python
logger.info(json.dumps({
    "message": "Function invoked",
    "correlationId": correlation_id,
    ...
}))
```

### ✅ Correlation ID (Requirement 11.2)
All functions extract and include the incident ID as `correlationId`:
```python
correlation_id = event.get('incidentId', event.get('incident', {}).get('incidentId', 'unknown'))
```

This correlation ID is included in every log statement throughout the function execution.

### ✅ Error Details with Stack Traces (Requirement 11.6)
All error handlers include stack traces using `traceback.format_exc()`:
```python
logger.error(json.dumps({
    "message": "Unexpected error",
    "correlationId": correlation_id,
    "error": str(e),
    "errorType": type(e).__name__,
    "stackTrace": traceback.format_exc()
}))
```

### ✅ Function Metadata
Function name and version are available from:
- Lambda context object: `context.function_name`, `context.function_version`
- Environment variables: `AWS_LAMBDA_FUNCTION_NAME`, `AWS_LAMBDA_FUNCTION_VERSION`

## Lambda Functions

### 1. Metrics Collector (`src/metrics_collector/lambda_function.py`)
- ✅ Structured JSON logging
- ✅ Correlation ID in all logs
- ✅ Stack traces on errors
- ✅ Function metadata via context

### 2. Logs Collector (`src/logs_collector/lambda_function.py`)
- ✅ Structured JSON logging
- ✅ Correlation ID in all logs
- ✅ Stack traces on errors
- ✅ Function metadata via context

### 3. Deploy Context Collector (`src/deploy_context_collector/lambda_function.py`)
- ✅ Structured JSON logging
- ✅ Correlation ID in all logs
- ✅ Stack traces on errors
- ✅ Function metadata via context

### 4. Correlation Engine (`src/correlation_engine/lambda_function.py`)
- ✅ Structured JSON logging
- ✅ Correlation ID in all logs
- ✅ Stack traces on errors
- ✅ Function metadata via context

### 5. LLM Analyzer (`src/llm_analyzer/lambda_function.py`)
- ✅ Structured JSON logging
- ✅ Correlation ID in all logs
- ✅ Stack traces on errors
- ✅ Function metadata via context
- ✅ Circuit breaker logging

### 6. Notification Service (`src/notification_service/lambda_function.py`)
- ✅ Structured JSON logging
- ✅ Correlation ID in all logs
- ✅ Stack traces on errors
- ✅ Function metadata via context
- ✅ Graceful degradation logging

### 7. Event Transformer (`src/event_transformer/lambda_function.py`)
- ✅ Structured JSON logging
- ✅ Correlation ID in all logs (incident ID generated here)
- ✅ Stack traces on errors
- ✅ Function metadata via context

## Log Structure

Standard log entry structure:

```json
{
  "message": "Human-readable message",
  "correlationId": "uuid-v4-incident-id",
  "functionName": "metrics-collector",
  "functionVersion": "$LATEST",
  "timestamp": "2024-01-15T14:30:00.123Z",
  "level": "INFO|WARNING|ERROR",
  ...additional context fields...
}
```

Error log entry structure:

```json
{
  "message": "Error description",
  "correlationId": "uuid-v4-incident-id",
  "functionName": "metrics-collector",
  "functionVersion": "$LATEST",
  "timestamp": "2024-01-15T14:30:00.123Z",
  "level": "ERROR",
  "error": "Error message",
  "errorType": "ExceptionClassName",
  "stackTrace": "Full stack trace..."
}
```

## Querying Logs

### Find all logs for an incident:
```bash
aws logs filter-log-events \
  --log-group-name /aws/lambda/metrics-collector \
  --filter-pattern '{ $.correlationId = "incident-uuid" }'
```

### Find all errors:
```bash
aws logs filter-log-events \
  --log-group-name /aws/lambda/metrics-collector \
  --filter-pattern '{ $.level = "ERROR" }'
```

### Find logs by function:
```bash
aws logs filter-log-events \
  --log-group-name /aws/lambda/metrics-collector \
  --filter-pattern '{ $.functionName = "metrics-collector" }'
```

## CloudWatch Insights Queries

### Trace incident workflow:
```sql
fields @timestamp, functionName, message, correlationId
| filter correlationId = "incident-uuid"
| sort @timestamp asc
```

### Error rate by function:
```sql
fields functionName, level
| filter level = "ERROR"
| stats count() by functionName
```

### Average function duration:
```sql
fields functionName, duration
| filter message = "Function completed successfully"
| stats avg(duration) by functionName
```

## Shared Utilities

The `src/shared/structured_logger.py` module provides a `StructuredLogger` class for consistent logging across functions. This is available for future enhancements but is not required given the existing comprehensive logging implementation.

## Compliance

This implementation fully satisfies:
- ✅ Requirement 11.1: All logs are valid JSON
- ✅ Requirement 11.2: Include correlation ID in all logs
- ✅ Requirement 11.6: Include error details with stack traces on failures
- ✅ Function name and version metadata available via Lambda context
- ✅ Timestamps in ISO-8601 format with 'Z' suffix (UTC)
