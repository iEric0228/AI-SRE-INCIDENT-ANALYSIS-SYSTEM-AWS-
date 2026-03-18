# Quick Start Guide

Get the test incident scenario running in 10 minutes.

## Step 1: Prerequisites (5 minutes)

### Create SSH Key Pair

If you don't have an SSH key pair in AWS:

```bash
# Create key pair
aws ec2 create-key-pair \
  --key-name ai-sre-test-key \
  --query 'KeyMaterial' \
  --output text > ~/.ssh/ai-sre-test-key.pem

# Set permissions
chmod 400 ~/.ssh/ai-sre-test-key.pem
```

### Get Your IP Address

```bash
curl ifconfig.me
```

Save this IP - you'll need it for SSH access.

## Step 2: Configure Terraform (2 minutes)

```bash
cd terraform/test-scenario

# Copy example config
cp terraform.tfvars.example terraform.tfvars

# Edit config
nano terraform.tfvars
```

Update these values:

```hcl
key_pair_name = "ai-sre-test-key"  # Your key pair name
allowed_ssh_cidr_blocks = ["YOUR_IP/32"]  # Your IP from Step 1
cpu_threshold = 50  # Or lower (10) for easier triggering
```

## Step 3: Deploy (2 minutes)

```bash
# Initialize Terraform
terraform init

# Deploy
terraform apply
```

Type `yes` when prompted.

Wait ~2 minutes for deployment to complete.

## Step 4: Trigger Alarm (2 minutes)

```bash
# Return to project root
cd ../..

# Trigger the alarm
./scripts/trigger-test-alarm.sh
```

This will:
1. SSH into the instance
2. Run CPU stress test
3. Monitor alarm state
4. Report when alarm triggers

## Step 5: Capture Data (1 minute)

```bash
./scripts/capture-alarm-event.sh
```

This captures:
- CloudWatch Alarm event
- Metrics data
- CloudTrail events
- CloudWatch Logs

## Verify Success

Check that these files exist:

```bash
ls -lh test-data/
```

You should see:
- `cloudwatch-alarm-event.json`
- `sample-metrics.json`
- `sample-cloudtrail-events.json`
- `sample-logs.json`

## View Captured Data

```bash
# View alarm event
cat test-data/cloudwatch-alarm-event.json | jq

# View metrics
cat test-data/sample-metrics.json | jq '.Datapoints | sort_by(.Timestamp) | .[-5:]'
```

## Cleanup

When done testing:

```bash
cd terraform/test-scenario
terraform destroy
```

Type `yes` when prompted.

## Troubleshooting

### Alarm Not Triggering

Lower the threshold:

```hcl
# In terraform.tfvars
cpu_threshold = 10
```

Then re-apply:

```bash
terraform apply
```

### Cannot SSH

Check security group allows your IP:

```bash
# Get your current IP
curl ifconfig.me

# Update terraform.tfvars with new IP
# Re-apply
terraform apply
```

### stress-ng Not Found

Wait 2-3 minutes after deployment for user data script to complete, then try again.

## Next Steps

✅ Test infrastructure deployed
✅ Alarm triggered successfully
✅ Event data captured

**Now you're ready to build the main system!**

Follow the deployment guide in [terraform/DEPLOYMENT.md](terraform/DEPLOYMENT.md) to deploy the full incident analysis pipeline.
