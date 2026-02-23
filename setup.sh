#!/bin/bash
# Setup script for AI-SRE Incident Analysis System development environment

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=== AI-SRE Incident Analysis System Setup ===${NC}\n"

# Check Python version
echo -e "${YELLOW}Checking Python version...${NC}"
PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}')
REQUIRED_VERSION="3.11"

if [[ "$(printf '%s\n' "$REQUIRED_VERSION" "$PYTHON_VERSION" | sort -V | head -n1)" != "$REQUIRED_VERSION" ]]; then
    echo -e "${RED}Error: Python 3.11+ required (found $PYTHON_VERSION)${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Python $PYTHON_VERSION${NC}\n"

# Check if virtual environment exists
if [ ! -d "venv" ]; then
    echo -e "${YELLOW}Creating virtual environment...${NC}"
    python3 -m venv venv
    echo -e "${GREEN}✓ Virtual environment created${NC}\n"
else
    echo -e "${GREEN}✓ Virtual environment already exists${NC}\n"
fi

# Activate virtual environment
echo -e "${YELLOW}Activating virtual environment...${NC}"
source venv/bin/activate
echo -e "${GREEN}✓ Virtual environment activated${NC}\n"

# Upgrade pip
echo -e "${YELLOW}Upgrading pip...${NC}"
pip install --upgrade pip > /dev/null 2>&1
echo -e "${GREEN}✓ pip upgraded${NC}\n"

# Install dependencies
echo -e "${YELLOW}Installing dependencies...${NC}"
pip install -r requirements-dev.txt > /dev/null 2>&1
echo -e "${GREEN}✓ Dependencies installed${NC}\n"

# Check AWS CLI
echo -e "${YELLOW}Checking AWS CLI...${NC}"
if command -v aws &> /dev/null; then
    AWS_VERSION=$(aws --version 2>&1 | awk '{print $1}')
    echo -e "${GREEN}✓ $AWS_VERSION${NC}\n"
else
    echo -e "${YELLOW}⚠ AWS CLI not found (optional for local development)${NC}\n"
fi

# Check Terraform
echo -e "${YELLOW}Checking Terraform...${NC}"
if command -v terraform &> /dev/null; then
    TF_VERSION=$(terraform version | head -n1)
    echo -e "${GREEN}✓ $TF_VERSION${NC}\n"
else
    echo -e "${YELLOW}⚠ Terraform not found (required for infrastructure deployment)${NC}\n"
fi

# Create .env file if it doesn't exist
if [ ! -f ".env" ]; then
    echo -e "${YELLOW}Creating .env file...${NC}"
    cat > .env <<EOF
# AWS Configuration
AWS_REGION=us-east-1
AWS_PROFILE=default

# Development Settings
ENVIRONMENT=dev
LOG_LEVEL=INFO

# Testing
HYPOTHESIS_PROFILE=dev
EOF
    echo -e "${GREEN}✓ .env file created${NC}\n"
else
    echo -e "${GREEN}✓ .env file already exists${NC}\n"
fi

# Summary
echo -e "${GREEN}=== Setup Complete ===${NC}\n"
echo "Next steps:"
echo "1. Activate virtual environment: source venv/bin/activate"
echo "2. Run tests: make test"
echo "3. Check code quality: make lint"
echo "4. Deploy test infrastructure: cd terraform/test-scenario && terraform apply"
echo ""
echo "For more commands, run: make help"
