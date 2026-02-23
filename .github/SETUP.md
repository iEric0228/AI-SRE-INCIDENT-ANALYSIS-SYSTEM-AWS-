# Quick Setup Guide for GitHub Actions CI/CD

This guide provides a streamlined setup process for the GitHub Actions CI/CD pipeline.

## Prerequisites

- AWS account with admin access
- AWS CLI configured locally
- GitHub repository created
- `jq` installed (for the setup script)

## Quick Setup (5 minutes)

### 1. Run the Automated Setup Script

```bash
./scripts/setup-github-oidc.sh
```

This script will:
- Create OIDC identity provider in AWS
- Create IAM roles for dev, staging, and production
- Create S3 bucket for Terraform state
- Create DynamoDB table for state locking
- Display the role ARNs you need to add to GitHub

### 2. Add GitHub Secrets

Navigate to your repository settings:
```
https://github.com/YOUR_ORG/YOUR_REPO/settings/secrets/actions
```

Add these three secrets with the ARNs from the setup script output:
- `AWS_ROLE_ARN_DEV`
- `AWS_ROLE_ARN_STAGING`
- `AWS_ROLE_ARN_PROD`

### 3. Configure GitHub Environments

1. Go to Settings → Environments
2. Create three environments: `dev`, `staging`, `production`
3. For the `production` environment:
   - Add required reviewers (team members who must approve deployments)
   - Optionally add a wait timer
   - Restrict deployment branches to `main` only

### 4. Update Terraform Backend Configuration

Edit `terraform/main.tf` and add the backend configuration:

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

Replace `YOUR_ACCOUNT_ID` with your AWS account ID (shown in setup script output).

### 5. Test the Pipeline

Create a test branch and PR:

```bash
git checkout -b test-ci-cd
git add .
git commit -m "Add GitHub Actions CI/CD pipeline"
git push origin test-ci-cd
```

Open a PR on GitHub and verify:
- ✅ Python linting passes
- ✅ Terraform validation passes
- ✅ Unit tests pass with coverage
- ✅ Property tests pass
- ✅ Infrastructure tests pass
- ✅ Terraform plan is commented on the PR

### 6. Deploy to Dev

Merge the PR to `main`:

```bash
git checkout main
git merge test-ci-cd
git push origin main
```

This will automatically:
- Run all tests again
- Deploy to dev environment
- Run integration tests
- Generate deployment summary

## Pipeline Overview

### On Pull Request
- Code quality checks (black, flake8, mypy, isort)
- Terraform validation
- Unit tests with coverage (80% minimum)
- Property tests (20 iterations)
- Infrastructure tests
- Terraform plan (commented on PR)

### On Merge to Main
- All PR checks
- Deploy to dev environment
- Integration tests against dev
- Generate deployment summary

### Manual Deployment
- Navigate to Actions → CI/CD Pipeline → Run workflow
- Select environment (staging or prod)
- For production, approval is required before deployment

## Troubleshooting

### "Could not assume role with OIDC"

**Check:**
1. OIDC provider exists: `aws iam list-open-id-connect-providers`
2. Role ARN is correct in GitHub secrets
3. Trust policy allows your repository
4. Repository name matches exactly (case-sensitive)

**Fix:**
```bash
# Re-run setup script
./scripts/setup-github-oidc.sh
```

### "Terraform state lock"

**Check:**
```bash
aws dynamodb scan --table-name ai-sre-terraform-locks
```

**Fix:**
```bash
cd terraform
terraform force-unlock LOCK_ID
```

### Tests Failing

**Property tests timeout:**
- Check Hypothesis profile: `echo $HYPOTHESIS_PROFILE`
- Should be `dev` (20 examples) for PRs, `ci` (100 examples) for main

**Integration tests fail:**
- Ensure dev environment is deployed
- Check Lambda functions exist: `aws lambda list-functions --query 'Functions[?starts_with(FunctionName, `ai-sre-`)]'`

### Deployment Fails

**Check Terraform logs:**
1. Go to Actions → Failed workflow → deploy-dev job
2. Expand "Terraform Apply" step
3. Look for specific error messages

**Common issues:**
- IAM permissions insufficient
- Resource quotas exceeded
- Naming conflicts (resources already exist)

## Cost Monitoring

Monitor costs in AWS Cost Explorer:
- Filter by tag: `Project: AI-SRE-Portfolio`
- Expected monthly cost: < $5 (mostly within free tier)

## Security Best Practices

✅ **Implemented:**
- OIDC authentication (no long-lived credentials)
- Least-privilege IAM roles
- Environment protection for production
- Secrets in GitHub Secrets (not code)
- Encrypted Terraform state

⚠️ **Additional Recommendations:**
- Enable branch protection rules on `main`
- Require status checks to pass before merging
- Enable "Require review from Code Owners"
- Set up AWS CloudTrail for audit logging
- Enable AWS Config for compliance monitoring

## Next Steps

After successful setup:

1. **Review Deployment Summary**
   - Download artifact from workflow run
   - Verify all resources created correctly

2. **Test the System**
   - Deploy test infrastructure: `cd terraform/test-scenario && terraform apply`
   - Trigger test alarm: `./scripts/trigger-test-alarm.sh`
   - Verify incident analysis workflow runs

3. **Monitor**
   - Check CloudWatch Logs for Lambda functions
   - Review Step Functions execution history
   - Monitor DynamoDB for incident records

4. **Iterate**
   - Make code changes
   - Create PR
   - Review Terraform plan
   - Merge and deploy

## Resources

- **Workflow File**: `.github/workflows/ci-cd.yml`
- **Detailed Documentation**: `.github/workflows/README.md`
- **Setup Script**: `scripts/setup-github-oidc.sh`
- **AWS OIDC Guide**: https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services

## Support

For issues or questions:
1. Check `.github/workflows/README.md` for detailed troubleshooting
2. Review GitHub Actions logs for specific errors
3. Check AWS CloudWatch Logs for Lambda/Step Functions errors
4. Verify IAM permissions with AWS Policy Simulator

---

**Setup Time**: ~5 minutes  
**First Deployment**: ~10 minutes  
**Subsequent Deployments**: ~5 minutes
