# Outputs for Test Scenario Infrastructure

output "instance_id" {
  description = "ID of the test EC2 instance"
  value       = aws_instance.test_instance.id
}

output "instance_public_ip" {
  description = "Public IP address of the test instance (for SSH access)"
  value       = aws_instance.test_instance.public_ip
}

output "instance_private_ip" {
  description = "Private IP address of the test instance"
  value       = aws_instance.test_instance.private_ip
}

output "alarm_arn" {
  description = "ARN of the CloudWatch Alarm"
  value       = aws_cloudwatch_metric_alarm.high_cpu.arn
}

output "alarm_name" {
  description = "Name of the CloudWatch Alarm"
  value       = aws_cloudwatch_metric_alarm.high_cpu.alarm_name
}

output "log_group_name" {
  description = "Name of the CloudWatch Log Group"
  value       = aws_cloudwatch_log_group.test_instance.name
}

output "security_group_id" {
  description = "ID of the security group"
  value       = aws_security_group.test_instance.id
}

output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh -i ~/.ssh/${var.key_pair_name}.pem ec2-user@${aws_instance.test_instance.public_ip}"
}

output "trigger_alarm_command" {
  description = "Command to trigger the CPU alarm"
  value       = "ssh -i ~/.ssh/${var.key_pair_name}.pem ec2-user@${aws_instance.test_instance.public_ip} 'stress-ng --cpu 1 --timeout 120s'"
}

output "check_alarm_state_command" {
  description = "AWS CLI command to check alarm state"
  value       = "aws cloudwatch describe-alarms --alarm-names ${aws_cloudwatch_metric_alarm.high_cpu.alarm_name} --query 'MetricAlarms[0].StateValue' --output text"
}
