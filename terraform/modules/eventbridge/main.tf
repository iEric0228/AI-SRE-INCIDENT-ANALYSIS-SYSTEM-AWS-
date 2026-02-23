# EventBridge and SNS Module
# This module creates EventBridge rules for CloudWatch Alarm detection and SNS topics for incident routing

# SNS Topic for Incident Notifications
resource "aws_sns_topic" "incident_notifications" {
  name              = "${var.project_name}-incident-notifications"
  display_name      = "AI-SRE Incident Analysis Notifications"
  kms_master_key_id = var.kms_key_id

  tags = var.tags
}

# SNS Topic Policy - Allow EventBridge to publish
resource "aws_sns_topic_policy" "incident_notifications" {
  arn = aws_sns_topic.incident_notifications.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEventBridgePublish"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.incident_notifications.arn
      }
    ]
  })
}

# SNS Subscription to Step Functions State Machine
resource "aws_sns_topic_subscription" "step_functions" {
  topic_arn = aws_sns_topic.incident_notifications.arn
  protocol  = "lambda"
  endpoint  = var.event_transformer_lambda_arn

  # Enable raw message delivery for cleaner event structure
  raw_message_delivery = false
}

# Dead Letter Queue for Failed Events
resource "aws_sqs_queue" "incident_dlq" {
  name                      = "${var.project_name}-incident-dlq"
  message_retention_seconds = 1209600 # 14 days
  kms_master_key_id         = var.kms_key_id

  tags = merge(
    var.tags,
    {
      Purpose = "Dead Letter Queue for failed incident events"
    }
  )
}

# SQS Queue Policy - Allow SNS to send messages
resource "aws_sqs_queue_policy" "incident_dlq" {
  queue_url = aws_sqs_queue.incident_dlq.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowSNSPublish"
        Effect = "Allow"
        Principal = {
          Service = "sns.amazonaws.com"
        }
        Action   = "SQS:SendMessage"
        Resource = aws_sqs_queue.incident_dlq.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_sns_topic.incident_notifications.arn
          }
        }
      }
    ]
  })
}

# Configure DLQ for SNS subscription
resource "aws_sns_topic_subscription" "dlq" {
  topic_arn = aws_sns_topic.incident_notifications.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.incident_dlq.arn

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.incident_dlq.arn
  })
}

# EventBridge Rule for CloudWatch Alarm State Changes
resource "aws_cloudwatch_event_rule" "alarm_state_change" {
  name        = "${var.project_name}-alarm-state-change"
  description = "Capture CloudWatch Alarm state changes to ALARM state"

  event_pattern = jsonencode({
    source      = ["aws.cloudwatch"]
    detail-type = ["CloudWatch Alarm State Change"]
    detail = {
      state = {
        value = ["ALARM"]
      }
    }
  })

  tags = var.tags
}

# EventBridge Target - Send to SNS Topic
resource "aws_cloudwatch_event_target" "sns" {
  rule      = aws_cloudwatch_event_rule.alarm_state_change.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.incident_notifications.arn

  # Transform the event to include incident metadata
  input_transformer {
    input_paths = {
      alarmName       = "$.detail.alarmName"
      alarmArn        = "$.detail.alarmArn"
      state           = "$.detail.state.value"
      timestamp       = "$.time"
      region          = "$.region"
      account         = "$.account"
      previousState   = "$.detail.previousState.value"
      stateReason     = "$.detail.state.reason"
      stateReasonData = "$.detail.state.reasonData"
      configuration   = "$.detail.configuration"
    }

    input_template = <<-EOT
    {
      "alarmName": <alarmName>,
      "alarmArn": <alarmArn>,
      "state": <state>,
      "timestamp": <timestamp>,
      "region": <region>,
      "account": <account>,
      "previousState": <previousState>,
      "stateReason": <stateReason>,
      "stateReasonData": <stateReasonData>,
      "configuration": <configuration>
    }
    EOT
  }

  # Configure retry policy for failed deliveries
  retry_policy {
    maximum_event_age_in_seconds = 3600 # 1 hour
    maximum_retry_attempts       = 3
  }

  # Send failed events to DLQ
  dead_letter_config {
    arn = aws_sqs_queue.incident_dlq.arn
  }
}

# CloudWatch Log Group for EventBridge Rule
resource "aws_cloudwatch_log_group" "eventbridge_rule" {
  name              = "/aws/events/${var.project_name}-alarm-state-change"
  retention_in_days = 7

  tags = var.tags
}

# CloudWatch Alarm for DLQ Messages (monitoring failed events)
resource "aws_cloudwatch_metric_alarm" "dlq_messages" {
  count = var.alarm_notification_topic_arn != "" ? 1 : 0

  alarm_name          = "${var.project_name}-incident-dlq-messages"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 300 # 5 minutes
  statistic           = "Average"
  threshold           = 0
  alarm_description   = "Alert when incident events fail to process and land in DLQ"
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = aws_sqs_queue.incident_dlq.name
  }

  alarm_actions = [var.alarm_notification_topic_arn]

  tags = var.tags
}
