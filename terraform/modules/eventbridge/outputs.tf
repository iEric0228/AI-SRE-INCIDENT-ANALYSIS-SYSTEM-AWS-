# EventBridge and SNS Module Outputs

output "sns_topic_arn" {
  description = "ARN of the SNS topic for incident notifications"
  value       = aws_sns_topic.incident_notifications.arn
}

output "sns_topic_name" {
  description = "Name of the SNS topic for incident notifications"
  value       = aws_sns_topic.incident_notifications.name
}

output "eventbridge_rule_name" {
  description = "Name of the EventBridge rule for CloudWatch Alarm state changes"
  value       = aws_cloudwatch_event_rule.alarm_state_change.name
}

output "eventbridge_rule_arn" {
  description = "ARN of the EventBridge rule for CloudWatch Alarm state changes"
  value       = aws_cloudwatch_event_rule.alarm_state_change.arn
}

output "dlq_arn" {
  description = "ARN of the dead letter queue for failed events"
  value       = aws_sqs_queue.incident_dlq.arn
}

output "dlq_url" {
  description = "URL of the dead letter queue for failed events"
  value       = aws_sqs_queue.incident_dlq.url
}

output "dlq_name" {
  description = "Name of the dead letter queue for failed events"
  value       = aws_sqs_queue.incident_dlq.name
}
