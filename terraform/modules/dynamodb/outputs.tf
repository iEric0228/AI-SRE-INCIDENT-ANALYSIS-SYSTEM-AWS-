output "table_name" {
  description = "Name of the DynamoDB table"
  value       = aws_dynamodb_table.incident_store.name
}

output "table_arn" {
  description = "ARN of the DynamoDB table"
  value       = aws_dynamodb_table.incident_store.arn
}

output "table_id" {
  description = "ID of the DynamoDB table"
  value       = aws_dynamodb_table.incident_store.id
}

output "resource_index_name" {
  description = "Name of the ResourceIndex GSI"
  value       = "ResourceIndex"
}

output "severity_index_name" {
  description = "Name of the SeverityIndex GSI"
  value       = "SeverityIndex"
}
