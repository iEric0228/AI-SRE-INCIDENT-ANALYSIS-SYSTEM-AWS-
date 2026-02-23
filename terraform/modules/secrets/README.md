# Secrets Manager Module

This module creates AWS Secrets Manager secrets for storing notification service credentials with the following features:

## Features

- **Slack Webhook Secret**: Stores Slack webhook URL for incident notifications
- **Email Configuration Secret**: Stores email configuration (SNS topic, from address, recipients)
- **KMS Encryption**: All secrets encrypted with customer-managed KMS key
- **Automatic Key Rotation**: KMS key rotation enabled annually
- **Secret Rotation**: Optional automatic rotation every 90 days
- **Recovery Window**: 7-day recovery window for deleted secrets
- **Resource Tagging**: Cost tracking and resource management

## Secrets Structure

### Slack Webhook Secret
```json
{
  "webhook_url": "https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXX"
}
```

### Email Configuration Secret
```json
{
  "sns_topic_arn": "arn:aws:sns:us-east-1:123456789012:incident-notifications",
  "from_address": "incidents@example.com",
  "recipient_emails": ["oncall@example.com", "sre-team@example.com"]
}
```

## Usage

### Basic Usage (No Rotation)
```hcl
module "secrets" {
  source = "./modules/secrets"

  project_name         = "incident-analysis"
  slack_webhook_url    = "https://hooks.slack.com/services/PLACEHOLDER"
  email_sns_topic_arn  = aws_sns_topic.notifications.arn
  email_from_address   = "incidents@example.com"
  email_recipients     = ["oncall@example.com"]

  tags = {
    Environment = "production"
    Project     = "AI-SRE-Portfolio"
  }
}
```

### With Automatic Rotation
```hcl
module "secrets" {
  source = "./modules/secrets"

  project_name         = "incident-analysis"
  slack_webhook_url    = "https://hooks.slack.com/services/PLACEHOLDER"
  email_sns_topic_arn  = aws_sns_topic.notifications.arn
  email_from_address   = "incidents@example.com"
  email_recipients     = ["oncall@example.com"]
  
  enable_rotation      = true
  rotation_days        = 90
  rotation_lambda_arn  = aws_lambda_function.secret_rotation.arn

  tags = {
    Environment = "production"
    Project     = "AI-SRE-Portfolio"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| project_name | Name of the project (used for resource naming) | string | "incident-analysis" | no |
| slack_webhook_url | Slack webhook URL (placeholder - should be updated after deployment) | string | "https://hooks.slack.com/services/PLACEHOLDER" | no |
| email_sns_topic_arn | ARN of the SNS topic for email notifications | string | "" | no |
| email_from_address | Email address to send notifications from | string | "incidents@example.com" | no |
| email_recipients | List of email addresses to receive incident notifications | list(string) | ["oncall@example.com"] | no |
| enable_rotation | Enable automatic secret rotation | bool | false | no |
| rotation_days | Number of days between automatic secret rotations | number | 90 | no |
| rotation_lambda_arn | ARN of the Lambda function for secret rotation | string | "" | no |
| tags | Additional tags to apply to secrets | map(string) | {} | no |

## Outputs

| Name | Description |
|------|-------------|
| slack_webhook_secret_arn | ARN of the Slack webhook secret |
| slack_webhook_secret_name | Name of the Slack webhook secret |
| email_config_secret_arn | ARN of the email configuration secret |
| email_config_secret_name | Name of the email configuration secret |
| kms_key_arn | ARN of the KMS key used for secret encryption |
| kms_key_id | ID of the KMS key used for secret encryption |
| kms_key_alias | Alias of the KMS key used for secret encryption |

## Updating Secrets

### Manual Update via AWS CLI
```bash
# Update Slack webhook URL
aws secretsmanager update-secret \
  --secret-id incident-analysis/slack-webhook \
  --secret-string '{"webhook_url":"https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXX"}'

# Update email configuration
aws secretsmanager update-secret \
  --secret-id incident-analysis/email-config \
  --secret-string '{"sns_topic_arn":"arn:aws:sns:us-east-1:123456789012:incident-notifications","from_address":"incidents@example.com","recipient_emails":["oncall@example.com"]}'
```

### Update via Terraform (Not Recommended)
The secret values have `lifecycle.ignore_changes` configured to prevent Terraform from overwriting manually updated secrets. To update via Terraform:

1. Remove the `lifecycle` block temporarily
2. Update the variable values
3. Run `terraform apply`
4. Re-add the `lifecycle` block

### Update via CI/CD
```yaml
# GitHub Actions example
- name: Update Slack Webhook Secret
  run: |
    aws secretsmanager update-secret \
      --secret-id incident-analysis/slack-webhook \
      --secret-string "{\"webhook_url\":\"${{ secrets.SLACK_WEBHOOK_URL }}\"}"
  env:
    AWS_REGION: us-east-1
```

## Retrieving Secrets in Lambda

### Python Example
```python
import boto3
import json

def get_slack_webhook():
    """Retrieve Slack webhook URL from Secrets Manager"""
    client = boto3.client('secretsmanager')
    
    response = client.get_secret_value(
        SecretId='incident-analysis/slack-webhook'
    )
    
    secret = json.loads(response['SecretString'])
    return secret['webhook_url']

def get_email_config():
    """Retrieve email configuration from Secrets Manager"""
    client = boto3.client('secretsmanager')
    
    response = client.get_secret_value(
        SecretId='incident-analysis/email-config'
    )
    
    config = json.loads(response['SecretString'])
    return {
        'sns_topic_arn': config['sns_topic_arn'],
        'from_address': config['from_address'],
        'recipients': config['recipient_emails']
    }
```

## Automatic Rotation

Automatic rotation requires a Lambda function that implements the rotation logic. The rotation function must:

1. Create a new secret value
2. Test the new secret (e.g., send a test notification)
3. Mark the new version as current
4. Delete the old version

### Rotation Lambda Example
```python
import boto3
import json

def lambda_handler(event, context):
    """Rotate Slack webhook secret"""
    service_client = boto3.client('secretsmanager')
    
    token = event['Token']
    step = event['Step']
    
    if step == "createSecret":
        # Generate new webhook URL (implementation depends on Slack API)
        new_webhook = generate_new_slack_webhook()
        service_client.put_secret_value(
            SecretId=event['SecretId'],
            ClientRequestToken=token,
            SecretString=json.dumps({"webhook_url": new_webhook}),
            VersionStages=['AWSPENDING']
        )
    
    elif step == "setSecret":
        # Test the new webhook
        test_slack_webhook(event['SecretId'], token)
    
    elif step == "testSecret":
        # Verify the webhook works
        verify_slack_webhook(event['SecretId'], token)
    
    elif step == "finishSecret":
        # Mark new version as current
        service_client.update_secret_version_stage(
            SecretId=event['SecretId'],
            VersionStage='AWSCURRENT',
            MoveToVersionId=token
        )
```

## Security Best Practices

1. **Never Hardcode Secrets**: Use Secrets Manager for all sensitive values
2. **Retrieve at Runtime**: Lambda functions should retrieve secrets on each invocation
3. **Use IAM Permissions**: Grant least-privilege access to secrets
4. **Enable Rotation**: Rotate secrets regularly (90 days recommended)
5. **Monitor Access**: Use CloudTrail to audit secret access
6. **Use KMS Encryption**: All secrets encrypted with customer-managed keys

## IAM Permissions

### Lambda Function Policy (Read-Only)
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue"
      ],
      "Resource": [
        "arn:aws:secretsmanager:*:*:secret:incident-analysis/slack-webhook*",
        "arn:aws:secretsmanager:*:*:secret:incident-analysis/email-config*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "kms:Decrypt"
      ],
      "Resource": "arn:aws:kms:*:*:key/*",
      "Condition": {
        "StringEquals": {
          "kms:ViaService": "secretsmanager.us-east-1.amazonaws.com"
        }
      }
    }
  ]
}
```

### Rotation Lambda Policy
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:DescribeSecret",
        "secretsmanager:GetSecretValue",
        "secretsmanager:PutSecretValue",
        "secretsmanager:UpdateSecretVersionStage"
      ],
      "Resource": "arn:aws:secretsmanager:*:*:secret:incident-analysis/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetRandomPassword"
      ],
      "Resource": "*"
    }
  ]
}
```

## Cost Optimization

- **Secrets Manager Pricing**: $0.40 per secret per month + $0.05 per 10,000 API calls
- **KMS Pricing**: $1.00 per key per month + $0.03 per 10,000 requests
- **Estimated Monthly Cost**: ~$2.80 for 2 secrets with moderate API usage

## Compliance

This module validates the following requirements:
- **14.1**: Store Slack webhook URLs in AWS Secrets Manager
- **14.2**: Store email configuration in AWS Secrets Manager
- **14.3**: Retrieve secrets at runtime using the AWS SDK
- **14.4**: No secrets in Terraform state files or Lambda environment variables
- **14.5**: Rotate secrets automatically every 90 days

## Troubleshooting

### Secret Not Found
```
Error: ResourceNotFoundException: Secrets Manager can't find the specified secret
```
**Solution**: Verify the secret name matches the module output. Check the AWS region.

### Access Denied
```
Error: AccessDeniedException: User is not authorized to perform: secretsmanager:GetSecretValue
```
**Solution**: Add the IAM policy shown above to the Lambda execution role.

### KMS Decryption Failed
```
Error: InvalidCiphertextException: The ciphertext refers to a customer master key that does not exist
```
**Solution**: Ensure the Lambda execution role has `kms:Decrypt` permission for the KMS key.

### Rotation Failed
```
Error: Rotation failed with error: Lambda function returned error
```
**Solution**: Check the rotation Lambda CloudWatch logs. Verify the rotation function has correct permissions.

## References

- [AWS Secrets Manager Documentation](https://docs.aws.amazon.com/secretsmanager/)
- [Rotating AWS Secrets Manager Secrets](https://docs.aws.amazon.com/secretsmanager/latest/userguide/rotating-secrets.html)
- [AWS KMS Key Rotation](https://docs.aws.amazon.com/kms/latest/developerguide/rotate-keys.html)
