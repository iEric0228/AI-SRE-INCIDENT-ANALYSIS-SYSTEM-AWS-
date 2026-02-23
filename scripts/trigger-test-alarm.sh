#!/bin/bash
# Script to trigger the test incident alarm by stressing CPU on the EC2 instance

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Test Incident Alarm Trigger Script ===${NC}\n"

# Check if we're in the right directory
if [ ! -d "terraform/test-scenario" ]; then
    echo -e "${RED}Error: Must run from project root directory${NC}"
    echo "Current directory: $(pwd)"
    exit 1
fi

# Get Terraform outputs
echo -e "${YELLOW}Getting instance details from Terraform...${NC}"
cd terraform/test-scenario

INSTANCE_IP=$(terraform output -raw instance_public_ip 2>/dev/null)
INSTANCE_ID=$(terraform output -raw instance_id 2>/dev/null)
ALARM_NAME=$(terraform output -raw alarm_name 2>/dev/null)
SSH_KEY_NAME=$(terraform output -json | jq -r '.ssh_command.value' | grep -oP '(?<=-i ~/.ssh/)[^ ]+' | sed 's/.pem//')

cd ../..

if [ -z "$INSTANCE_IP" ] || [ -z "$INSTANCE_ID" ]; then
    echo -e "${RED}Error: Could not get instance details from Terraform${NC}"
    echo "Make sure you've run 'terraform apply' in terraform/test-scenario/"
    exit 1
fi

echo -e "${GREEN}✓ Instance ID: ${INSTANCE_ID}${NC}"
echo -e "${GREEN}✓ Instance IP: ${INSTANCE_IP}${NC}"
echo -e "${GREEN}✓ Alarm Name: ${ALARM_NAME}${NC}\n"

# Check current alarm state
echo -e "${YELLOW}Checking current alarm state...${NC}"
CURRENT_STATE=$(aws cloudwatch describe-alarms \
    --alarm-names "$ALARM_NAME" \
    --query 'MetricAlarms[0].StateValue' \
    --output text 2>/dev/null || echo "UNKNOWN")

echo -e "Current state: ${CURRENT_STATE}\n"

if [ "$CURRENT_STATE" = "ALARM" ]; then
    echo -e "${YELLOW}Warning: Alarm is already in ALARM state${NC}"
    echo "You may want to reset it first with: ./scripts/reset-test-alarm.sh"
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
fi

# Test SSH connectivity
echo -e "${YELLOW}Testing SSH connectivity...${NC}"
if ! ssh -i ~/.ssh/${SSH_KEY_NAME}.pem \
    -o ConnectTimeout=10 \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o LogLevel=ERROR \
    ec2-user@${INSTANCE_IP} "echo 'SSH connection successful'" 2>/dev/null; then
    echo -e "${RED}Error: Cannot connect to instance via SSH${NC}"
    echo "Troubleshooting steps:"
    echo "1. Check security group allows SSH from your IP"
    echo "2. Verify instance is running: aws ec2 describe-instances --instance-ids $INSTANCE_ID"
    echo "3. Check key pair exists: ls ~/.ssh/${SSH_KEY_NAME}.pem"
    exit 1
fi

echo -e "${GREEN}✓ SSH connection successful${NC}\n"

# Check if stress-ng is installed
echo -e "${YELLOW}Checking if stress-ng is installed...${NC}"
if ! ssh -i ~/.ssh/${SSH_KEY_NAME}.pem \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o LogLevel=ERROR \
    ec2-user@${INSTANCE_IP} "which stress-ng" &>/dev/null; then
    echo -e "${YELLOW}stress-ng not found, installing...${NC}"
    ssh -i ~/.ssh/${SSH_KEY_NAME}.pem \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o LogLevel=ERROR \
        ec2-user@${INSTANCE_IP} \
        "sudo amazon-linux-extras install epel -y && sudo yum install -y stress-ng" 2>&1 | grep -v "Warning: Permanently added"
    echo -e "${GREEN}✓ stress-ng installed${NC}\n"
else
    echo -e "${GREEN}✓ stress-ng already installed${NC}\n"
fi

# Trigger CPU stress
echo -e "${GREEN}=== Triggering CPU Stress Test ===${NC}"
echo "This will run for 2 minutes (120 seconds)"
echo "The alarm should trigger within 1-2 minutes"
echo ""

ssh -i ~/.ssh/${SSH_KEY_NAME}.pem \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o LogLevel=ERROR \
    ec2-user@${INSTANCE_IP} \
    "nohup stress-ng --cpu 1 --timeout 120s > /tmp/stress.log 2>&1 &" 2>&1 | grep -v "Warning: Permanently added"

echo -e "${GREEN}✓ CPU stress test started${NC}\n"

# Monitor alarm state
echo -e "${YELLOW}Monitoring alarm state (checking every 15 seconds)...${NC}"
echo "Press Ctrl+C to stop monitoring"
echo ""

CHECKS=0
MAX_CHECKS=12  # 3 minutes total

while [ $CHECKS -lt $MAX_CHECKS ]; do
    sleep 15
    CHECKS=$((CHECKS + 1))
    
    STATE=$(aws cloudwatch describe-alarms \
        --alarm-names "$ALARM_NAME" \
        --query 'MetricAlarms[0].StateValue' \
        --output text 2>/dev/null || echo "UNKNOWN")
    
    TIMESTAMP=$(date '+%H:%M:%S')
    
    if [ "$STATE" = "ALARM" ]; then
        echo -e "${GREEN}[$TIMESTAMP] ✓ ALARM STATE REACHED!${NC}"
        echo ""
        echo -e "${GREEN}=== Success! ===${NC}"
        echo "The alarm has been triggered successfully."
        echo ""
        echo "Next steps:"
        echo "1. Capture the alarm event: ./scripts/capture-alarm-event.sh"
        echo "2. View metrics in AWS Console"
        echo "3. Reset the alarm when done: ./scripts/reset-test-alarm.sh"
        exit 0
    elif [ "$STATE" = "INSUFFICIENT_DATA" ]; then
        echo -e "[$TIMESTAMP] State: ${YELLOW}INSUFFICIENT_DATA${NC} (waiting for metrics...)"
    else
        echo "[$TIMESTAMP] State: $STATE (waiting for CPU spike...)"
    fi
done

echo ""
echo -e "${YELLOW}Monitoring timeout reached (3 minutes)${NC}"
echo "The alarm may still trigger. Check manually with:"
echo "  aws cloudwatch describe-alarms --alarm-names $ALARM_NAME"
echo ""
echo "If the alarm didn't trigger, try:"
echo "1. Lower the threshold: Set cpu_threshold = 10 in terraform.tfvars"
echo "2. Run terraform apply again"
echo "3. Re-run this script"
