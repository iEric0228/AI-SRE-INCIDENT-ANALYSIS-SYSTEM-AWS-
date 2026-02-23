#!/bin/bash
# Script to reset the test alarm to OK state

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Test Alarm Reset Script ===${NC}\n"

# Check if we're in the right directory
if [ ! -d "terraform/test-scenario" ]; then
    echo -e "${RED}Error: Must run from project root directory${NC}"
    exit 1
fi

# Get Terraform outputs
echo -e "${YELLOW}Getting instance details from Terraform...${NC}"
cd terraform/test-scenario

INSTANCE_IP=$(terraform output -raw instance_public_ip 2>/dev/null)
ALARM_NAME=$(terraform output -raw alarm_name 2>/dev/null)
SSH_KEY_NAME=$(terraform output -json | jq -r '.ssh_command.value' | grep -oP '(?<=-i ~/.ssh/)[^ ]+' | sed 's/.pem//')

cd ../..

if [ -z "$INSTANCE_IP" ] || [ -z "$ALARM_NAME" ]; then
    echo -e "${RED}Error: Could not get instance details from Terraform${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Instance IP: ${INSTANCE_IP}${NC}"
echo -e "${GREEN}✓ Alarm Name: ${ALARM_NAME}${NC}\n"

# Check current alarm state
echo -e "${YELLOW}Checking current alarm state...${NC}"
CURRENT_STATE=$(aws cloudwatch describe-alarms \
    --alarm-names "$ALARM_NAME" \
    --query 'MetricAlarms[0].StateValue' \
    --output text 2>/dev/null || echo "UNKNOWN")

echo -e "Current state: ${CURRENT_STATE}\n"

if [ "$CURRENT_STATE" = "OK" ]; then
    echo -e "${GREEN}Alarm is already in OK state. Nothing to do.${NC}"
    exit 0
fi

# Stop any running stress tests
echo -e "${YELLOW}Stopping any running stress tests...${NC}"
ssh -i ~/.ssh/${SSH_KEY_NAME}.pem \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o LogLevel=ERROR \
    ec2-user@${INSTANCE_IP} \
    "pkill stress-ng || true" 2>&1 | grep -v "Warning: Permanently added"

echo -e "${GREEN}✓ Stress tests stopped${NC}\n"

# Wait for CPU to normalize
echo -e "${YELLOW}Waiting for CPU to normalize (checking every 15 seconds)...${NC}"
echo "This may take 2-3 minutes"
echo "Press Ctrl+C to stop monitoring"
echo ""

CHECKS=0
MAX_CHECKS=20  # 5 minutes total

while [ $CHECKS -lt $MAX_CHECKS ]; do
    sleep 15
    CHECKS=$((CHECKS + 1))
    
    STATE=$(aws cloudwatch describe-alarms \
        --alarm-names "$ALARM_NAME" \
        --query 'MetricAlarms[0].StateValue' \
        --output text 2>/dev/null || echo "UNKNOWN")
    
    TIMESTAMP=$(date '+%H:%M:%S')
    
    if [ "$STATE" = "OK" ]; then
        echo -e "${GREEN}[$TIMESTAMP] ✓ ALARM RESET TO OK STATE!${NC}"
        echo ""
        echo -e "${GREEN}=== Success! ===${NC}"
        echo "The alarm has been reset successfully."
        echo "You can now trigger it again with: ./scripts/trigger-test-alarm.sh"
        exit 0
    else
        echo "[$TIMESTAMP] State: $STATE (waiting for CPU to normalize...)"
    fi
done

echo ""
echo -e "${YELLOW}Monitoring timeout reached (5 minutes)${NC}"
echo "The alarm may still reset. Check manually with:"
echo "  aws cloudwatch describe-alarms --alarm-names $ALARM_NAME"
