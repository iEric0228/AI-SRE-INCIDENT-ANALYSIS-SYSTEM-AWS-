# CloudWatch Alarms Module Outputs

output "ops_alerts_topic_arn" {
  description = "ARN of the SNS topic for operational alerts"
  value       = aws_sns_topic.ops_alerts.arn
}

output "ops_alerts_topic_name" {
  description = "Name of the SNS topic for operational alerts"
  value       = aws_sns_topic.ops_alerts.name
}

output "workflow_failures_alarm_arn" {
  description = "ARN of the workflow failures alarm"
  value       = aws_cloudwatch_metric_alarm.workflow_failures.arn
}

output "workflow_timeouts_alarm_arn" {
  description = "ARN of the workflow timeouts alarm"
  value       = aws_cloudwatch_metric_alarm.workflow_timeouts.arn
}

output "llm_analyzer_errors_alarm_arn" {
  description = "ARN of the LLM analyzer errors alarm"
  value       = aws_cloudwatch_metric_alarm.llm_analyzer_errors.arn
}

output "llm_analyzer_timeouts_alarm_arn" {
  description = "ARN of the LLM analyzer timeouts alarm"
  value       = aws_cloudwatch_metric_alarm.llm_analyzer_timeouts.arn
}

output "notification_errors_alarm_arn" {
  description = "ARN of the notification service errors alarm"
  value       = aws_cloudwatch_metric_alarm.notification_errors.arn
}

output "notification_delivery_failures_alarm_arn" {
  description = "ARN of the notification delivery failures alarm"
  value       = aws_cloudwatch_metric_alarm.notification_delivery_failures.arn
}

output "collector_failures_alarm_arn" {
  description = "ARN of the collector failures alarm"
  value       = aws_cloudwatch_metric_alarm.collector_failures.arn
}

output "dynamodb_throttles_alarm_arn" {
  description = "ARN of the DynamoDB throttles alarm"
  value       = aws_cloudwatch_metric_alarm.dynamodb_throttles.arn
}

output "correlation_engine_errors_alarm_arn" {
  description = "ARN of the correlation engine errors alarm"
  value       = aws_cloudwatch_metric_alarm.correlation_engine_errors.arn
}

output "dashboard_name" {
  description = "Name of the CloudWatch dashboard for system health"
  value       = aws_cloudwatch_dashboard.system_health.dashboard_name
}

output "dashboard_arn" {
  description = "ARN of the CloudWatch dashboard for system health"
  value       = aws_cloudwatch_dashboard.system_health.dashboard_arn
}
