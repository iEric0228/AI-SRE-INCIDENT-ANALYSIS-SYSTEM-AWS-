#!/bin/bash
# Setup script for GitHub Actions OIDC authentication with AWS
# This script creates the necessary IAM resources for GitHub Actions to deploy via OIDC

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=== GitHub Actions OIDC Setup for AWS ===${NC}\n"

# Check prerequisites
if ! command -v aws &> /dev/null; then
    echo -e "${RED}Error: AWS CLI not found. Please install it first.${NC}"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq not found. Please install it first.${NC}"
    exit 1
fi

# Get AWS account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo -e "${GREEN}AWS Account ID: ${AWS_ACCOUNT_ID}${NC}\n"

# Prompt for GitHub repository details
read -p "Enter your GitHub organization/username: " GITHUB_ORG
read -p "Enter your GitHub repository name: " GITHUB_REPO

GITHUB_REPO_FULL="${GITHUB_ORG}/${GITHUB_REPO}"
echo -e "\n${YELLOW}GitHub Repository: ${GITHUB_REPO_FULL}${NC}\n"

# Confirm before proceeding
read -p "Continue with setup? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Setup cancelled."
    exit 0
fi

# ============================================================================
# Step 1: Create OIDC Identity Provider
# ============================================================================

echo -e "\n${YELLOW}Step 1: Creating OIDC Identity Provider...${NC}"

OIDC_PROVIDER_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"

# Check if provider already exists
if aws iam get-open-id-connect-provider --open-id-connect-provider-arn "$OIDC_PROVIDER_ARN" &> /dev/null; then
    echo -e "${GREEN}✓ OIDC provider already exists${NC}"
else
    aws iam create-open-id-connect-provider \
        --url https://token.actions.githubusercontent.com \
        --client-id-list sts.amazonaws.com \
        --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1 \
        > /dev/null
    echo -e "${GREEN}✓ OIDC provider created${NC}"
fi

# ============================================================================
# Step 2: Create IAM Roles for Each Environment
# ============================================================================

create_iam_role() {
    local ENV=$1
    local ROLE_NAME="GitHubActions-AI-SRE-${ENV}"
    
    echo -e "\n${YELLOW}Creating IAM role: ${ROLE_NAME}...${NC}"
    
    # Trust policy
    cat > /tmp/trust-policy-${ENV}.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "${OIDC_PROVIDER_ARN}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:${GITHUB_REPO_FULL}:*"
        }
      }
    }
  ]
}
EOF

    # Permissions policy
    cat > /tmp/permissions-policy-${ENV}.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "TerraformStateManagement",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket",
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:DeleteItem"
      ],
      "Resource": [
        "arn:aws:s3:::ai-sre-terraform-state-${AWS_ACCOUNT_ID}",
        "arn:aws:s3:::ai-sre-terraform-state-${AWS_ACCOUNT_ID}/*",
        "arn:aws:dynamodb:*:${AWS_ACCOUNT_ID}:table/ai-sre-terraform-locks"
      ]
    },
    {
      "Sid": "LambdaManagement",
      "Effect": "Allow",
      "Action": [
        "lambda:CreateFunction",
        "lambda:DeleteFunction",
        "lambda:GetFunction",
        "lambda:GetFunctionConfiguration",
        "lambda:UpdateFunctionCode",
        "lambda:UpdateFunctionConfiguration",
        "lambda:ListFunctions",
        "lambda:ListTags",
        "lambda:TagResource",
        "lambda:UntagResource",
        "lambda:PublishVersion",
        "lambda:CreateAlias",
        "lambda:UpdateAlias",
        "lambda:GetPolicy",
        "lambda:AddPermission",
        "lambda:RemovePermission"
      ],
      "Resource": "arn:aws:lambda:*:${AWS_ACCOUNT_ID}:function:ai-sre-*"
    },
    {
      "Sid": "StepFunctionsManagement",
      "Effect": "Allow",
      "Action": [
        "states:CreateStateMachine",
        "states:DeleteStateMachine",
        "states:DescribeStateMachine",
        "states:UpdateStateMachine",
        "states:ListStateMachines",
        "states:TagResource",
        "states:UntagResource"
      ],
      "Resource": "arn:aws:states:*:${AWS_ACCOUNT_ID}:stateMachine:ai-sre-*"
    },
    {
      "Sid": "DynamoDBManagement",
      "Effect": "Allow",
      "Action": [
        "dynamodb:CreateTable",
        "dynamodb:DeleteTable",
        "dynamodb:DescribeTable",
        "dynamodb:UpdateTable",
        "dynamodb:ListTables",
        "dynamodb:TagResource",
        "dynamodb:UntagResource",
        "dynamodb:UpdateTimeToLive",
        "dynamodb:DescribeTimeToLive"
      ],
      "Resource": "arn:aws:dynamodb:*:${AWS_ACCOUNT_ID}:table/ai-sre-*"
    },
    {
      "Sid": "EventBridgeManagement",
      "Effect": "Allow",
      "Action": [
        "events:PutRule",
        "events:DeleteRule",
        "events:DescribeRule",
        "events:PutTargets",
        "events:RemoveTargets",
        "events:ListRules",
        "events:ListTargetsByRule",
        "events:TagResource",
        "events:UntagResource"
      ],
      "Resource": "arn:aws:events:*:${AWS_ACCOUNT_ID}:rule/ai-sre-*"
    },
    {
      "Sid": "SNSManagement",
      "Effect": "Allow",
      "Action": [
        "sns:CreateTopic",
        "sns:DeleteTopic",
        "sns:GetTopicAttributes",
        "sns:SetTopicAttributes",
        "sns:Subscribe",
        "sns:Unsubscribe",
        "sns:ListTopics",
        "sns:ListSubscriptionsByTopic",
        "sns:TagResource",
        "sns:UntagResource"
      ],
      "Resource": "arn:aws:sns:*:${AWS_ACCOUNT_ID}:ai-sre-*"
    },
    {
      "Sid": "IAMManagement",
      "Effect": "Allow",
      "Action": [
        "iam:CreateRole",
        "iam:DeleteRole",
        "iam:GetRole",
        "iam:UpdateRole",
        "iam:PutRolePolicy",
        "iam:DeleteRolePolicy",
        "iam:GetRolePolicy",
        "iam:AttachRolePolicy",
        "iam:DetachRolePolicy",
        "iam:ListRolePolicies",
        "iam:ListAttachedRolePolicies",
        "iam:PassRole",
        "iam:TagRole",
        "iam:UntagRole"
      ],
      "Resource": "arn:aws:iam::${AWS_ACCOUNT_ID}:role/ai-sre-*"
    },
    {
      "Sid": "CloudWatchManagement",
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:DeleteLogGroup",
        "logs:DescribeLogGroups",
        "logs:PutRetentionPolicy",
        "logs:TagLogGroup",
        "logs:UntagLogGroup",
        "cloudwatch:PutMetricAlarm",
        "cloudwatch:DeleteAlarms",
        "cloudwatch:DescribeAlarms"
      ],
      "Resource": "*"
    },
    {
      "Sid": "SecretsManagement",
      "Effect": "Allow",
      "Action": [
        "secretsmanager:CreateSecret",
        "secretsmanager:DeleteSecret",
        "secretsmanager:DescribeSecret",
        "secretsmanager:GetSecretValue",
        "secretsmanager:PutSecretValue",
        "secretsmanager:TagResource",
        "secretsmanager:UntagResource"
      ],
      "Resource": "arn:aws:secretsmanager:*:${AWS_ACCOUNT_ID}:secret:ai-sre-*"
    },
    {
      "Sid": "SSMManagement",
      "Effect": "Allow",
      "Action": [
        "ssm:PutParameter",
        "ssm:DeleteParameter",
        "ssm:GetParameter",
        "ssm:GetParameters",
        "ssm:DescribeParameters",
        "ssm:AddTagsToResource",
        "ssm:RemoveTagsFromResource"
      ],
      "Resource": "arn:aws:ssm:*:${AWS_ACCOUNT_ID}:parameter/ai-sre/*"
    },
    {
      "Sid": "VPCReadOnly",
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeSubnets",
        "ec2:DescribeVpcs"
      ],
      "Resource": "*"
    }
  ]
}
EOF

    # Create role
    if aws iam get-role --role-name "$ROLE_NAME" &> /dev/null; then
        echo -e "${YELLOW}Role already exists, updating trust policy...${NC}"
        aws iam update-assume-role-policy \
            --role-name "$ROLE_NAME" \
            --policy-document file:///tmp/trust-policy-${ENV}.json
    else
        aws iam create-role \
            --role-name "$ROLE_NAME" \
            --assume-role-policy-document file:///tmp/trust-policy-${ENV}.json \
            --description "GitHub Actions role for AI-SRE ${ENV} environment" \
            --tags Key=Project,Value=AI-SRE-Portfolio Key=Environment,Value=${ENV} \
            > /dev/null
    fi
    
    # Attach permissions policy
    POLICY_NAME="${ROLE_NAME}-Policy"
    
    # Delete existing policy if it exists
    if aws iam get-role-policy --role-name "$ROLE_NAME" --policy-name "$POLICY_NAME" &> /dev/null; then
        aws iam delete-role-policy --role-name "$ROLE_NAME" --policy-name "$POLICY_NAME"
    fi
    
    aws iam put-role-policy \
        --role-name "$ROLE_NAME" \
        --policy-name "$POLICY_NAME" \
        --policy-document file:///tmp/permissions-policy-${ENV}.json
    
    ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/${ROLE_NAME}"
    echo -e "${GREEN}✓ Role created: ${ROLE_ARN}${NC}"
    
    # Clean up temp files
    rm /tmp/trust-policy-${ENV}.json /tmp/permissions-policy-${ENV}.json
    
    echo "$ROLE_ARN"
}

# Create roles for each environment
DEV_ROLE_ARN=$(create_iam_role "Dev")
STAGING_ROLE_ARN=$(create_iam_role "Staging")
PROD_ROLE_ARN=$(create_iam_role "Prod")

# ============================================================================
# Step 3: Create Terraform Backend Resources
# ============================================================================

echo -e "\n${YELLOW}Step 3: Creating Terraform backend resources...${NC}"

BUCKET_NAME="ai-sre-terraform-state-${AWS_ACCOUNT_ID}"
TABLE_NAME="ai-sre-terraform-locks"

# Create S3 bucket
if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
    echo -e "${GREEN}✓ S3 bucket already exists${NC}"
else
    aws s3api create-bucket \
        --bucket "$BUCKET_NAME" \
        --region us-east-1 \
        > /dev/null
    
    aws s3api put-bucket-versioning \
        --bucket "$BUCKET_NAME" \
        --versioning-configuration Status=Enabled
    
    aws s3api put-bucket-encryption \
        --bucket "$BUCKET_NAME" \
        --server-side-encryption-configuration '{
            "Rules": [{
                "ApplyServerSideEncryptionByDefault": {
                    "SSEAlgorithm": "AES256"
                }
            }]
        }'
    
    echo -e "${GREEN}✓ S3 bucket created: ${BUCKET_NAME}${NC}"
fi

# Create DynamoDB table
if aws dynamodb describe-table --table-name "$TABLE_NAME" &> /dev/null; then
    echo -e "${GREEN}✓ DynamoDB table already exists${NC}"
else
    aws dynamodb create-table \
        --table-name "$TABLE_NAME" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST \
        --region us-east-1 \
        --tags Key=Project,Value=AI-SRE-Portfolio \
        > /dev/null
    
    echo -e "${GREEN}✓ DynamoDB table created: ${TABLE_NAME}${NC}"
fi

# ============================================================================
# Summary
# ============================================================================

echo -e "\n${GREEN}=== Setup Complete ===${NC}\n"
echo "Add these secrets to your GitHub repository:"
echo ""
echo "Repository: https://github.com/${GITHUB_REPO_FULL}/settings/secrets/actions"
echo ""
echo "Secrets to add:"
echo "  AWS_ROLE_ARN_DEV     = ${DEV_ROLE_ARN}"
echo "  AWS_ROLE_ARN_STAGING = ${STAGING_ROLE_ARN}"
echo "  AWS_ROLE_ARN_PROD    = ${PROD_ROLE_ARN}"
echo ""
echo "Terraform backend configuration:"
echo "  Bucket: ${BUCKET_NAME}"
echo "  Table:  ${TABLE_NAME}"
echo "  Region: us-east-1"
echo ""
echo "Next steps:"
echo "1. Add the secrets to GitHub (see URL above)"
echo "2. Update terraform/main.tf with backend configuration"
echo "3. Configure GitHub environment protection for 'production'"
echo "4. Push code to trigger the CI/CD pipeline"
echo ""
echo "For more details, see .github/workflows/README.md"
