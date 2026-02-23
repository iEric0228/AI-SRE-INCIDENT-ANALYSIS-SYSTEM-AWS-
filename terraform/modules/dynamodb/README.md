# DynamoDB Table Module

This module creates a DynamoDB table for storing incident analysis records with the following features:

## Features

- **Primary Key**: Composite key with `incidentId` (partition key) and `timestamp` (sort key)
- **Global Secondary Indexes**:
  - `ResourceIndex`: Query incidents by resource ARN and time range
  - `SeverityIndex`: Query incidents by severity level and time range
- **On-Demand Billing**: Pay-per-request pricing for cost optimization
- **TTL Configuration**: Automatic deletion of records after 90 days
- **Encryption at Rest**: KMS encryption for data security
- **Point-in-Time Recovery**: Backup and restore capability
- **Resource Tagging**: Cost tracking and resource management

## Schema

### Primary Key
- **Partition Key**: `incidentId` (String) - UUID v4 identifier
- **Sort Key**: `timestamp` (String) - ISO-8601 timestamp

### Attributes
- `incidentId` (String) - Unique incident identifier
- `timestamp` (String) - Incident occurrence time in ISO-8601 format
- `resourceArn` (String) - ARN of the affected AWS resource
- `resourceType` (String) - Type of resource (lambda, ec2, rds, etc.)
- `alarmName` (String) - Name of the CloudWatch alarm that triggered
- `severity` (String) - Incident severity (critical, high, medium, low)
- `structuredContext` (Map) - Merged data from all collectors
- `analysisReport` (Map) - LLM-generated analysis and recommendations
- `notificationStatus` (Map) - Delivery status for Slack and email
- `ttl` (Number) - Unix timestamp for automatic expiration (90 days)

### Global Secondary Indexes

#### ResourceIndex
- **Partition Key**: `resourceArn`
- **Sort Key**: `timestamp`
- **Projection**: ALL
- **Use Case**: Query all incidents for a specific resource

#### SeverityIndex
- **Partition Key**: `severity`
- **Sort Key**: `timestamp`
- **Projection**: ALL
- **Use Case**: Query high-severity incidents across all resources

## Usage

```hcl
module "incident_store" {
  source = "./modules/dynamodb"

  table_name  = "incident-analysis-store"
  kms_key_arn = aws_kms_key.incident_store.arn

  tags = {
    Environment = "production"
    Project     = "AI-SRE-Portfolio"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| table_name | Name of the DynamoDB table | string | "incident-analysis-store" | no |
| kms_key_arn | ARN of the KMS key for encryption | string | n/a | yes |
| tags | Additional tags to apply | map(string) | {} | no |

## Outputs

| Name | Description |
|------|-------------|
| table_name | Name of the DynamoDB table |
| table_arn | ARN of the DynamoDB table |
| table_id | ID of the DynamoDB table |
| resource_index_name | Name of the ResourceIndex GSI |
| severity_index_name | Name of the SeverityIndex GSI |

## TTL Configuration

The table is configured with Time-To-Live (TTL) on the `ttl` attribute. Records are automatically deleted 90 days after the incident timestamp. The `ttl` field should be set to:

```python
import time
from datetime import datetime, timedelta

# Calculate TTL (90 days from incident)
incident_time = datetime.fromisoformat(incident['timestamp'])
ttl_time = incident_time + timedelta(days=90)
ttl_unix = int(ttl_time.timestamp())
```

## Query Examples

### Query by Incident ID
```python
response = dynamodb.get_item(
    TableName='incident-analysis-store',
    Key={
        'incidentId': {'S': 'uuid-value'},
        'timestamp': {'S': '2024-01-15T14:30:00Z'}
    }
)
```

### Query by Resource ARN
```python
response = dynamodb.query(
    TableName='incident-analysis-store',
    IndexName='ResourceIndex',
    KeyConditionExpression='resourceArn = :arn AND #ts BETWEEN :start AND :end',
    ExpressionAttributeNames={'#ts': 'timestamp'},
    ExpressionAttributeValues={
        ':arn': {'S': 'arn:aws:lambda:us-east-1:123456789012:function:my-function'},
        ':start': {'S': '2024-01-01T00:00:00Z'},
        ':end': {'S': '2024-01-31T23:59:59Z'}
    }
)
```

### Query by Severity
```python
response = dynamodb.query(
    TableName='incident-analysis-store',
    IndexName='SeverityIndex',
    KeyConditionExpression='severity = :sev AND #ts > :start',
    ExpressionAttributeNames={'#ts': 'timestamp'},
    ExpressionAttributeValues={
        ':sev': {'S': 'high'},
        ':start': {'S': '2024-01-01T00:00:00Z'}
    }
)
```

## Cost Optimization

- **On-Demand Billing**: No capacity planning required, pay only for actual usage
- **TTL**: Automatic deletion reduces storage costs
- **Efficient Indexes**: GSIs use ALL projection for query flexibility

## Security

- **Encryption at Rest**: All data encrypted with customer-managed KMS key
- **IAM Permissions**: Least-privilege access via IAM roles
- **Point-in-Time Recovery**: Protection against accidental deletion

## Compliance

This module validates the following requirements:
- **9.1**: Persist complete incident records
- **9.2**: Store all required fields
- **9.3**: Support querying by resource ARN, time range, and severity
- **9.4**: Retain incidents for 90 days with automatic expiration
- **9.5**: Encrypt all data at rest using AWS KMS
- **17.4**: Use on-demand billing mode for cost optimization
- **17.6**: Tag all resources for cost tracking
