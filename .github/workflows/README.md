# GitHub Actions CI/CD Pipeline

This directory contains the GitHub Actions workflows for the AI-SRE Incident Analysis System.

## Workflows

### `ci-cd.yml` - Main CI/CD Pipeline

Comprehensive pipeline that handles code quality, testing, and deployment across environments.

#### Triggers

- **Pull Request**: Runs validation and testing
- **Push to main**: Deploys to dev environment
- **Manual Dispatch**: Deploy to staging or production

#### Jobs

**Code Quality:**
- `python-lint`: black, flake8, mypy, isort
- `terraform-validate`: Format check and validation

**Testing:**
- `unit-tests`: pytest with 80% coverage requirement
- `property-tests`: Hypothesis-based property testing (20 iterations on PR, 100 on merge)
- `infrastructure-tests`: Terraform configuration validation
- `integration-tests`: End-to-end tests against dev environment (post-deployment)

**Deployment:**
- `terraform-plan`: Generate and comment plan on PRs
- `deploy-dev`: Auto-deploy to dev on merge to main
- `deploy-staging`: Manual deployment to staging
- `deploy-prod`: Manual deployment to production (requires approval)

## AWS OIDC Setup

The pipeline uses OpenID Connect (OIDC) for secure, credential-free AWS authentication.

### Prerequisites

1. AWS account with appropriate permissions
2. GitHub repository with Actions enabled
3. AWS IAM OIDC identity provider configured

### Step 1: Create OIDC Identity Provider in AWS

```bash
# Using AWS CLI
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

Or via AWS Console:
1. Navigate to IAM → Identity providers
2. Click "Add provider"
3. Provider type: OpenID Connect
4. Provider URL: `https://token.actions.githubusercontent.com`
5. Audience: `sts.amazonaws.com`

### Step 2: Create IAM Roles for Each Environment

Create three IAM roles (dev, staging, prod) with trust policies that allow GitHub Actions to assume them.

#### Trust Policy Template

Replace `YOUR_GITHUB_ORG` and `YOUR_REPO_NAME`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::YOUR_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:YOUR_GITHUB_ORG/YOUR_REPO_NAME:*"
        }
      }
    }
  ]
}
```

#### Permissions Policy

Attach a policy with permissions for Terraform operations:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "lambda:*",
        "states:*",
        "dynamodb:*",
        "events:*",
        "sns:*",
        "iam:*",
        "logs:*",
        "cloudwatch:*",
        "secretsmanager:*",
        "ssm:*",
        "bedrock:*",
        "s3:*",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeSubnets",
        "ec2:DescribeVpcs"
      ],
      "Resource": "*"
    }
  ]
}
```

**Note**: Restrict permissions further based on your security requirements.

### Step 3: Create Terraform Backend (Optional)

For state management, create an S3 bucket and DynamoDB table:

```bash
# Create S3 bucket for state
aws s3api create-bucket \
  --bucket ai-sre-terraform-state-YOUR_ACCOUNT_ID \
  --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket ai-sre-terraform-state-YOUR_ACCOUNT_ID \
  --versioning-configuration Status=Enabled

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name ai-sre-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

Update `terraform/main.tf` backend configuration:

```hcl
terraform {
  backend "s3" {
    bucket         = "ai-sre-terraform-state-YOUR_ACCOUNT_ID"
    key            = "ai-sre-incident-analysis/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "ai-sre-terraform-locks"
    encrypt        = true
  }
}
```

### Step 4: Configure GitHub Secrets

Add the following secrets to your GitHub repository:

1. Navigate to Settings → Secrets and variables → Actions
2. Add repository secrets:

| Secret Name | Description | Example Value |
|-------------|-------------|---------------|
| `AWS_ROLE_ARN_DEV` | IAM role ARN for dev environment | `arn:aws:iam::123456789012:role/GitHubActions-Dev` |
| `AWS_ROLE_ARN_STAGING` | IAM role ARN for staging environment | `arn:aws:iam::123456789012:role/GitHubActions-Staging` |
| `AWS_ROLE_ARN_PROD` | IAM role ARN for production environment | `arn:aws:iam::123456789012:role/GitHubActions-Prod` |

### Step 5: Configure GitHub Environments

Set up environment protection rules:

1. Navigate to Settings → Environments
2. Create three environments: `dev`, `staging`, `production`

**Production Environment Protection:**
- Required reviewers: Add team members who must approve
- Wait timer: Optional delay before deployment
- Deployment branches: Restrict to `main` branch only

## Usage

### Automatic Deployment (Dev)

Merging to `main` automatically deploys to dev:

```bash
git checkout main
git pull
git merge feature-branch
git push origin main
```

### Manual Deployment (Staging/Production)

1. Navigate to Actions tab in GitHub
2. Select "CI/CD Pipeline" workflow
3. Click "Run workflow"
4. Select environment (staging or prod)
5. Click "Run workflow"

For production, approval is required before deployment proceeds.

## Workflow Outputs

### Coverage Reports

- Unit test coverage uploaded to Codecov
- HTML coverage report available as artifact

### Terraform Plans

- PR comments include Terraform plan summary
- Full plan available in job logs

### Deployment Summaries

- Generated for each deployment
- Available as workflow artifacts
- Includes Terraform outputs and metadata

## Troubleshooting

### OIDC Authentication Fails

**Error**: `Error: Could not assume role with OIDC`

**Solutions**:
1. Verify OIDC provider exists in AWS IAM
2. Check trust policy allows your repository
3. Ensure role ARN secret is correct
4. Verify `id-token: write` permission in workflow

### Terraform State Lock

**Error**: `Error acquiring the state lock`

**Solutions**:
1. Check DynamoDB table exists
2. Verify IAM permissions for DynamoDB
3. Manually release lock if stuck:
   ```bash
   terraform force-unlock LOCK_ID
   ```

### Test Failures

**Property tests timeout**:
- Reduce `max_examples` in Hypothesis profile
- Check for infinite loops in generators

**Integration tests fail**:
- Verify dev environment is deployed
- Check AWS credentials are valid
- Ensure Lambda functions are deployed

### Deployment Failures

**Terraform apply fails**:
1. Check Terraform plan for issues
2. Verify IAM permissions
3. Check resource quotas in AWS
4. Review CloudWatch Logs for Lambda errors

## Security Best Practices

1. **No Long-Lived Credentials**: OIDC eliminates need for AWS access keys
2. **Least Privilege**: IAM roles have minimum required permissions
3. **Environment Protection**: Production requires manual approval
4. **Audit Trail**: All deployments logged in GitHub Actions
5. **Secret Management**: Sensitive values in GitHub Secrets, not code

## Cost Optimization

- GitHub Actions: 2,000 minutes/month free for public repos
- AWS resources: Minimal cost within free tier
- Terraform state: S3 + DynamoDB costs < $1/month

## Monitoring

Monitor workflow health:

1. **GitHub Actions Dashboard**: View run history and success rates
2. **AWS CloudWatch**: Monitor deployed resources
3. **Codecov**: Track test coverage trends
4. **Terraform Cloud** (optional): Enhanced state management

## Future Enhancements

- [ ] Add smoke tests after deployment
- [ ] Implement blue-green deployments
- [ ] Add performance benchmarking
- [ ] Integrate security scanning (Snyk, Trivy)
- [ ] Add Slack notifications for deployments
- [ ] Implement automatic rollback on failure

## References

- [GitHub Actions OIDC](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
- [AWS IAM OIDC](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc.html)
- [Terraform GitHub Actions](https://developer.hashicorp.com/terraform/tutorials/automation/github-actions)
- [Hypothesis Testing](https://hypothesis.readthedocs.io/)
