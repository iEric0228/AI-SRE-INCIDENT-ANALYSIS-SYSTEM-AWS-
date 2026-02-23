# EventBridge and SNS Module

This module creates the event detection and routing infrastructure for the AI-Assisted SRE Incident Analysis System. It captures CloudWatch Alarm state changes and routes them to the incident analysis workflow.

## Features

- **EventBridge Rule**: Captures CloudWatch Alarm state changes to ALARM state
- **Event Pattern Filtering**: Only processes alarms in ALARM state (not OK or INSUFFICIENT_DATA)
- **SNS Topic**: Central routing point for incident notifications
- **Event Transformation**: Enriches alarm events with metadata before routing
- **Dead Letter Queue**: Captures failed events for troubleshooting
- **Retry Policy**: Automatic retry with exponential backoff for transient failures
- **DLQ Monitoring**: CloudWatch alarm for failed event detection
- **Encryption**: KMS encryption for SNS topic and SQS queue

## Architecture

```
CloudWatch Alarms
    ↓ (state change to ALARM)
EventBridge Rule (filter: state=ALARM)
    ↓ (transform event)
SNS Topic
    ↓
Lambda (Event Transformer)
    ↓
Step Functions Orchestrator
    
Failed Events → Dead Letter Queue → CloudWatch Alarm
```

## Event Flow

1. **CloudWatch Alarm** transitions to ALARM state
2. **EventBridge Rule** captures the state change event
3. **Event Pattern Filter** ensures only ALARM states are processed
4. **Input Transformer** enriches the event with metadata
5. **SNS Topic** receives the transformed event
6. **Lambda Subscription** triggers the event transformer function
7. **Step Functions** orchestrator begins incident analysis workflow
8. **Failed Events** are sent to DLQ for investigation

## Event Pattern

The EventBridge rule uses the following event pattern to filter CloudWatch Alarm state changes:

```json
{
  "source": ["aws.cloudwatch"],
  "detail-type": ["CloudWatch Alarm State Change"],
  "detail": {
    "state": {
      "value": ["ALARM"]
    }
  }
}
```

This pattern ensures:
- Only CloudWatch Alarm events are captured
- Only state changes to ALARM are processed
- OK and INSUFFICIENT_DATA states are ignored

## Event Transformation

The input transformer enriches alarm events with the following fields:

- `alarmName`: Name of the CloudWatch alarm
- `alarmArn`: ARN of the CloudWatch alarm
- `state`: Current alarm state (ALARM)
- `timestamp`: Event timestamp in ISO-8601 format
- `region`: AWS region where the alarm fired
- `account`: AWS account ID
- `previousState`: Previous alarm state
- `stateReason`: Human-readable reason for state change
- `stateReasonData`: JSON data with metric details
- `configuration`: Alarm configuration (metric, threshold, etc.)

## Dead Letter Queue

Failed events are sent to an SQS dead letter queue for investigation. The DLQ:

- Retains messages for 14 days
- Is encrypted with KMS
- Has a CloudWatch alarm that triggers when messages appear
- Allows manual inspection and replay of failed events

## Usage

```hcl
module "eventbridge" {
  source = "./modules/eventbridge"

  project_name                   = "ai-sre-incident-analysis"
  event_transformer_lambda_arn   = module.lambda.event_transformer_arn
  kms_key_id                     = aws_kms_key.incident_store.id
  alarm_notification_topic_arn   = aws_sns_topic.ops_alerts.arn

  tags = {
    Environment = "production"
    Project     = "AI-SRE-Portfolio"
  }
}
```

## Inputs

| Name | Description | Type | Required |
|------|-------------|------|----------|
| project_name | Name of the project, used for resource naming | string | yes |
| event_transformer_lambda_arn | ARN of the Lambda function that transforms CloudWatch Alarm events | string | yes |
| kms_key_id | KMS key ID for encrypting SNS topic and SQS queue | string | yes |
| alarm_notification_topic_arn | ARN of SNS topic for CloudWatch alarm notifications (for DLQ monitoring) | string | yes |
| tags | Tags to apply to all resources | map(string) | no |

## Outputs

| Name | Description |
|------|-------------|
| sns_topic_arn | ARN of the SNS topic for incident notifications |
| sns_topic_name | Name of the SNS topic for incident notifications |
| eventbridge_rule_name | Name of the EventBridge rule for CloudWatch Alarm state changes |
| eventbridge_rule_arn | ARN of the EventBridge rule for CloudWatch Alarm state changes |
| dlq_arn | ARN of the dead letter queue for failed events |
| dlq_url | URL of the dead letter queue for failed events |
| dlq_name | Name of the dead letter queue for failed events |

## Retry Policy

The EventBridge target is configured with the following retry policy:

- **Maximum Event Age**: 1 hour
- **Maximum Retry Attempts**: 3
- **Backoff**: Exponential (2s, 4s, 8s)

If an event fails after all retries, it is sent to the dead letter queue.

## Monitoring

The module creates a CloudWatch alarm that monitors the DLQ for messages:

- **Metric**: `ApproximateNumberOfMessagesVisible`
- **Threshold**: > 0 messages
- **Evaluation Period**: 5 minutes
- **Action**: Publish to alarm notification topic

This ensures operations teams are alerted when events fail to process.

## Security

- **Encryption**: SNS topic and SQS queue are encrypted with customer-managed KMS key
- **IAM Policies**: Least-privilege policies for EventBridge and SNS
- **Topic Policy**: Only EventBridge can publish to the SNS topic
- **Queue Policy**: Only SNS can send messages to the DLQ

## Cost Optimization

- **EventBridge**: No charge for rules, only for events processed
- **SNS**: $0.50 per million requests
- **SQS**: First 1 million requests per month are free
- **CloudWatch Logs**: 7-day retention minimizes storage costs

## Compliance

This module validates the following requirements:

- **1.1**: CloudWatch Alarms publish events to EventBridge
- **1.2**: EventBridge triggers the orchestrator via SNS
- **1.3**: Event payload includes alarm name, resource ARN, timestamp, and alarm state
- **1.4**: Multiple simultaneous alarms are processed independently

## Testing

To test the EventBridge rule:

1. Create a test CloudWatch alarm
2. Trigger the alarm to ALARM state
3. Verify the event appears in CloudWatch Logs
4. Verify the Lambda function is invoked
5. Verify the Step Functions workflow starts

Example test alarm:

```bash
aws cloudwatch put-metric-alarm \
  --alarm-name test-high-cpu \
  --alarm-description "Test alarm for incident analysis" \
  --metric-name CPUUtilization \
  --namespace AWS/EC2 \
  --statistic Average \
  --period 60 \
  --evaluation-periods 1 \
  --threshold 50 \
  --comparison-operator GreaterThanThreshold \
  --dimensions Name=InstanceId,Value=i-1234567890abcdef0

# Trigger the alarm by setting the alarm state
aws cloudwatch set-alarm-state \
  --alarm-name test-high-cpu \
  --state-value ALARM \
  --state-reason "Testing incident analysis workflow"
```

## Troubleshooting

### Events not reaching Step Functions

1. Check EventBridge rule is enabled
2. Verify event pattern matches alarm events
3. Check SNS topic policy allows EventBridge to publish
4. Verify Lambda subscription is active
5. Check Lambda function logs for errors

### Events in Dead Letter Queue

1. Check DLQ messages in SQS console
2. Review message body for error details
3. Check Lambda function permissions
4. Verify Step Functions state machine exists
5. Replay failed events after fixing issues

### High DLQ alarm firing

1. Investigate root cause of failures
2. Check Lambda function logs
3. Verify IAM permissions
4. Check Step Functions execution history
5. Consider increasing retry attempts if transient failures

## Future Enhancements

- **Event Filtering**: Add filters for specific alarm names or namespaces
- **Rate Limiting**: Implement throttling for high-volume alarm scenarios
- **Event Deduplication**: Prevent duplicate processing of rapid alarm flapping
- **Multi-Region**: Support cross-region alarm aggregation
- **Custom Metrics**: Add custom CloudWatch metrics for event processing
