# Outputs for Step Functions module

output "state_machine_arn" {
  description = "ARN of the Step Functions state machine"
  value       = aws_sfn_state_machine.incident_orchestrator.arn
}

output "state_machine_name" {
  description = "Name of the Step Functions state machine"
  value       = aws_sfn_state_machine.incident_orchestrator.name
}

output "state_machine_id" {
  description = "ID of the Step Functions state machine"
  value       = aws_sfn_state_machine.incident_orchestrator.id
}

output "log_group_arn" {
  description = "ARN of the CloudWatch Log Group for state machine logs"
  value       = aws_cloudwatch_log_group.state_machine.arn
}

output "log_group_name" {
  description = "Name of the CloudWatch Log Group for state machine logs"
  value       = aws_cloudwatch_log_group.state_machine.name
}

