# Test Scenario Infrastructure

This Terraform configuration creates a simple test environment for the AI-assisted incident analysis system.

## What This Creates

- **EC2 Instance** (t2.micro): Test instance that will trigger the alarm
- **CloudWatch Alarm**: Monitors CPU utilization (threshold: 50%)
- **Security Group**: Allows SSH access for triggering load
- **IAM Role**: Grants CloudWatch Agent permissions
- **CloudWatch Log Group**: Stores instance logs

## Prerequisites

1. **AWS Account** with appropriate permissions
2. **AWS CLI** configured with credentials
3. **Terraform** installed (v1.0+)
4. **SSH Key Pair** created in AWS EC2 console

### Create SSH Key Pair

If you don't have an SSH key pair:

```bash
# In AWS Console: EC2 > Key Pairs > Create Key Pair
# Or via CLI:
aws ec2 create-key-pair \
  --key-name my-test-key \
  --query 'KeyMaterial' \
  --output text > ~/.ssh/my-test-key.pem

chmod 400 ~/.ssh/my-test-key.pem
```

## Setup Instructions

### Step 1: Configure Variables

```bash
# Copy the example variables file
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
nano terraform.tfvars
```

**Important**: Update these values:
- `key_pair_name`: Your SSH key pair name
- `allowed_ssh_cidr_blocks`: Your IP address (for security)

To find your IP:
```bash
curl ifconfig.me
```

Then set:
```hcl
allowed_ssh_cidr_blocks = ["YOUR_IP/32"]
```

### Step 2: Initialize Terraform

```bash
terraform init
```

### Step 3: Review the Plan

```bash
terraform plan
```

Verify the resources to be created:
- 1 EC2 instance
- 1 CloudWatch Alarm
- 1 Security Group
- 1 IAM Role + Instance Profile
- 1 CloudWatch Log Group

### Step 4: Deploy

```bash
terraform apply
```

Type `yes` when prompted.

Deployment takes ~2-3 minutes.

### Step 5: Save Outputs

```bash
terraform output
```

Save these values for later use:
- `instance_id`: For querying metrics
- `instance_public_ip`: For SSH access
- `alarm_name`: For checking alarm state
- `ssh_command`: Ready-to-use SSH command

## Triggering the Test Alarm

### Option 1: Automated Script (Recommended)

```bash
# From project root
cd ../../scripts
./trigger-test-alarm.sh
```

### Option 2: Manual SSH

```bash
# Get the SSH command from Terraform output
terraform output -raw ssh_command

# Or manually:
ssh -i ~/.ssh/YOUR_KEY.pem ec2-user@$(terraform output -raw instance_public_ip)

# Once connected, run CPU stress test:
stress-ng --cpu 1 --timeout 120s

# Exit SSH
exit
```

### Option 3: Lower the Threshold

For easier testing, lower the CPU threshold to 10%:

```hcl
# In terraform.tfvars
cpu_threshold = 10
```

Then re-apply:
```bash
terraform apply
```

The alarm will trigger naturally as the instance runs.

## Verifying the Alarm

Check alarm state:

```bash
# Using Terraform output
$(terraform output -raw check_alarm_state_command)

# Or manually
aws cloudwatch describe-alarms \
  --alarm-names test-incident-high-cpu \
  --query 'MetricAlarms[0].StateValue' \
  --output text
```

Expected output when triggered: `ALARM`

## Viewing Metrics

```bash
# Get instance ID
INSTANCE_ID=$(terraform output -raw instance_id)

# Query CPU metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=InstanceId,Value=$INSTANCE_ID \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 \
  --statistics Average,Maximum
```

## Viewing Logs

```bash
# Get log group name
LOG_GROUP=$(terraform output -raw log_group_name)

# View recent logs
aws logs tail $LOG_GROUP --follow
```

## Resetting the Alarm

```bash
# Stop any running stress tests
ssh -i ~/.ssh/YOUR_KEY.pem ec2-user@$(terraform output -raw instance_public_ip) \
  'pkill stress-ng'

# Wait 2-3 minutes for CPU to normalize
# Alarm will automatically return to OK state
```

## Cost Estimate

- **EC2 t2.micro**: ~$0.01/hour (free tier: 750 hours/month)
- **CloudWatch Alarm**: Free (first 10 alarms)
- **CloudWatch Logs**: ~$0.50/GB ingested (minimal for this test)
- **Data Transfer**: Negligible

**Total**: < $1 for testing (likely $0 if within free tier)

## Cleanup

When done testing:

```bash
terraform destroy
```

Type `yes` when prompted.

This removes all resources and stops charges.

## Troubleshooting

### Alarm Not Triggering

**Problem**: Alarm stays in OK state.

**Solutions**:
1. Lower threshold: `cpu_threshold = 10` in terraform.tfvars
2. Increase stress duration: `stress-ng --cpu 1 --timeout 300s`
3. Check metrics are publishing: See "Viewing Metrics" above
4. Verify alarm configuration: `aws cloudwatch describe-alarms --alarm-names test-incident-high-cpu`

### Cannot SSH

**Problem**: Connection timeout.

**Solutions**:
1. Check security group allows your IP:
   ```bash
   aws ec2 describe-security-groups \
     --group-ids $(terraform output -raw security_group_id)
   ```
2. Verify instance is running:
   ```bash
   aws ec2 describe-instances \
     --instance-ids $(terraform output -raw instance_id) \
     --query 'Reservations[0].Instances[0].State.Name'
   ```
3. Update your IP in terraform.tfvars if it changed
4. Re-apply: `terraform apply`

### stress-ng Not Found

**Problem**: `stress-ng: command not found`

**Solutions**:
1. Wait 2-3 minutes after instance launch (user data script is still running)
2. Manually install:
   ```bash
   sudo amazon-linux-extras install epel -y
   sudo yum install -y stress-ng
   ```

### No Logs in CloudWatch

**Problem**: Log group is empty.

**Solutions**:
1. CloudWatch Agent takes 2-3 minutes to start
2. Check agent status:
   ```bash
   ssh ... 'sudo systemctl status amazon-cloudwatch-agent'
   ```
3. Logs are optional - system works without them

## Next Steps

Once the alarm has triggered:

1. ✅ Capture event payloads (see `../../docs/DEMO.md`)
2. ✅ Use captured data for unit tests
3. ✅ Start building Lambda functions (Task 1 in tasks.md)

## Files in This Directory

- `main.tf`: Main infrastructure definition
- `variables.tf`: Input variables with validation
- `outputs.tf`: Output values for use in scripts
- `terraform.tfvars.example`: Example configuration
- `README.md`: This file

## Architecture

```
┌─────────────────────────────────────┐
│  EC2 Instance (t2.micro)            │
│  - Amazon Linux 2                   │
│  - CloudWatch Agent                 │
│  - stress-ng installed              │
└──────────────┬──────────────────────┘
               │
               │ CPU Metrics
               ▼
┌─────────────────────────────────────┐
│  CloudWatch Alarm                   │
│  - Threshold: 50% CPU               │
│  - Period: 60 seconds               │
│  - Evaluation: 1 period             │
└──────────────┬──────────────────────┘
               │
               │ State Change Event
               ▼
        (Future: SNS → EventBridge
         → Step Functions)
```
