output "slack_webhook_secret_arn" {
  description = "ARN of the Slack webhook secret"
  value       = aws_secretsmanager_secret.slack_webhook.arn
}

output "slack_webhook_secret_name" {
  description = "Name of the Slack webhook secret"
  value       = aws_secretsmanager_secret.slack_webhook.name
}

output "email_config_secret_arn" {
  description = "ARN of the email configuration secret"
  value       = aws_secretsmanager_secret.email_config.arn
}

output "email_config_secret_name" {
  description = "Name of the email configuration secret"
  value       = aws_secretsmanager_secret.email_config.name
}

output "kms_key_arn" {
  description = "ARN of the KMS key used for secret encryption"
  value       = aws_kms_key.secrets.arn
}

output "kms_key_id" {
  description = "ID of the KMS key used for secret encryption"
  value       = aws_kms_key.secrets.key_id
}

output "kms_key_alias" {
  description = "Alias of the KMS key used for secret encryption"
  value       = aws_kms_alias.secrets.name
}
