#!/bin/bash
# Script to capture the CloudWatch Alarm event from EventBridge/CloudWatch Logs

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Capture Alarm Event Script ===${NC}\n"

# Check if we're in the right directory
if [ ! -d "terraform/test-scenario" ]; then
    echo -e "${RED}Error: Must run from project root directory${NC}"
    exit 1
fi

# Create test-data directory if it doesn't exist
mkdir -p test-data

# Get alarm name from Terraform
cd terraform/test-scenario
ALARM_NAME=$(terraform output -raw alarm_name 2>/dev/null)
ALARM_ARN=$(terraform output -raw alarm_arn 2>/dev/null)
INSTANCE_ID=$(terraform output -raw instance_id 2>/dev/null)
cd ../..

if [ -z "$ALARM_NAME" ]; then
    echo -e "${RED}Error: Could not get alarm details from Terraform${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Alarm Name: ${ALARM_NAME}${NC}"
echo -e "${GREEN}✓ Alarm ARN: ${ALARM_ARN}${NC}\n"

# Check if alarm has been triggered
echo -e "${YELLOW}Checking alarm state...${NC}"
ALARM_STATE=$(aws cloudwatch describe-alarms \
    --alarm-names "$ALARM_NAME" \
    --query 'MetricAlarms[0].StateValue' \
    --output text 2>/dev/null || echo "UNKNOWN")

if [ "$ALARM_STATE" != "ALARM" ]; then
    echo -e "${YELLOW}Warning: Alarm is not in ALARM state (current: $ALARM_STATE)${NC}"
    echo "You may want to trigger it first with: ./scripts/trigger-test-alarm.sh"
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
fi

# Get alarm details and create a sample event
echo -e "${YELLOW}Fetching alarm details...${NC}"

ALARM_DETAILS=$(aws cloudwatch describe-alarms \
    --alarm-names "$ALARM_NAME" \
    --output json)

# Extract key details
ALARM_DESCRIPTION=$(echo "$ALARM_DETAILS" | jq -r '.MetricAlarms[0].AlarmDescription')
METRIC_NAME=$(echo "$ALARM_DETAILS" | jq -r '.MetricAlarms[0].MetricName')
NAMESPACE=$(echo "$ALARM_DETAILS" | jq -r '.MetricAlarms[0].Namespace')
THRESHOLD=$(echo "$ALARM_DETAILS" | jq -r '.MetricAlarms[0].Threshold')
STATE_REASON=$(echo "$ALARM_DETAILS" | jq -r '.MetricAlarms[0].StateReason')

# Create a sample CloudWatch Alarm event (this is what EventBridge would receive)
cat > test-data/cloudwatch-alarm-event.json <<EOF
{
  "version": "0",
  "id": "$(uuidgen | tr '[:upper:]' '[:lower:]')",
  "detail-type": "CloudWatch Alarm State Change",
  "source": "aws.cloudwatch",
  "account": "$(aws sts get-caller-identity --query Account --output text)",
  "time": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "region": "$(aws configure get region)",
  "resources": [
    "$ALARM_ARN"
  ],
  "detail": {
    "alarmName": "$ALARM_NAME",
    "state": {
      "value": "ALARM",
      "reason": "$STATE_REASON",
      "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    },
    "previousState": {
      "value": "OK",
      "timestamp": "$(date -u -d '5 minutes ago' +%Y-%m-%dT%H:%M:%SZ)"
    },
    "configuration": {
      "description": "$ALARM_DESCRIPTION",
      "metrics": [
        {
          "id": "m1",
          "metricStat": {
            "metric": {
              "namespace": "$NAMESPACE",
              "name": "$METRIC_NAME",
              "dimensions": {
                "InstanceId": "$INSTANCE_ID"
              }
            },
            "period": 60,
            "stat": "Average"
          },
          "returnData": true
        }
      ]
    }
  }
}
EOF

echo -e "${GREEN}✓ Created test-data/cloudwatch-alarm-event.json${NC}\n"

# Capture actual metrics
echo -e "${YELLOW}Capturing CloudWatch metrics...${NC}"

aws cloudwatch get-metric-statistics \
    --namespace "$NAMESPACE" \
    --metric-name "$METRIC_NAME" \
    --dimensions Name=InstanceId,Value="$INSTANCE_ID" \
    --start-time "$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S)" \
    --end-time "$(date -u +%Y-%m-%dT%H:%M:%S)" \
    --period 60 \
    --statistics Average,Maximum,Minimum \
    --output json > test-data/sample-metrics.json

echo -e "${GREEN}✓ Created test-data/sample-metrics.json${NC}\n"

# Capture CloudTrail events
echo -e "${YELLOW}Capturing CloudTrail events...${NC}"

aws cloudtrail lookup-events \
    --lookup-attributes AttributeKey=ResourceName,AttributeValue="$INSTANCE_ID" \
    --start-time "$(date -u -d '24 hours ago' +%Y-%m-%dT%H:%M:%S)" \
    --max-results 50 \
    --output json > test-data/sample-cloudtrail-events.json 2>/dev/null || \
    echo '{"Events": []}' > test-data/sample-cloudtrail-events.json

echo -e "${GREEN}✓ Created test-data/sample-cloudtrail-events.json${NC}\n"

# Try to capture logs (may be empty if CloudWatch Agent not configured)
echo -e "${YELLOW}Attempting to capture CloudWatch Logs...${NC}"

LOG_GROUP="/aws/ec2/test-incident-instance"

if aws logs describe-log-groups --log-group-name-prefix "$LOG_GROUP" --output json | jq -e '.logGroups | length > 0' > /dev/null 2>&1; then
    aws logs filter-log-events \
        --log-group-name "$LOG_GROUP" \
        --start-time "$(($(date +%s) - 3600))000" \
        --filter-pattern "ERROR" \
        --output json > test-data/sample-logs.json 2>/dev/null || \
        echo '{"events": []}' > test-data/sample-logs.json
    
    echo -e "${GREEN}✓ Created test-data/sample-logs.json${NC}\n"
else
    echo -e "${YELLOW}⚠ Log group not found (CloudWatch Agent may not be configured)${NC}"
    echo '{"events": [], "note": "CloudWatch Agent not configured"}' > test-data/sample-logs.json
    echo -e "${YELLOW}✓ Created empty test-data/sample-logs.json${NC}\n"
fi

# Summary
echo -e "${GREEN}=== Capture Complete ===${NC}\n"
echo "Captured event payloads:"
echo "  ✓ test-data/cloudwatch-alarm-event.json"
echo "  ✓ test-data/sample-metrics.json"
echo "  ✓ test-data/sample-cloudtrail-events.json"
echo "  ✓ test-data/sample-logs.json"
echo ""
echo "These files can now be used as test fixtures for your Lambda functions."
echo ""
echo "Next steps:"
echo "1. Review the captured data: cat test-data/cloudwatch-alarm-event.json | jq"
echo "2. Use these files in unit tests"
echo "3. Start building Lambda functions (Task 1 in tasks.md)"
