#!/bin/bash

# Setup LocalStack IAM Resources for Spacelift Integration
# This script creates an admin role that Spacelift can assume

set -euo pipefail

# Configuration
LOCALSTACK_ENDPOINT="http://localhost:4566"
AWS_REGION="us-east-1"
ROLE_NAME="SpaceliftAdminRole"
POLICY_NAME="SpaceliftAdminPolicy"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

success() {
    echo -e "${GREEN}✓ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

error() {
    echo -e "${RED}✗ $1${NC}"
}

# Check if the AWS CLI is installed
check_aws_cli() {
    if ! command -v aws >/dev/null 2>&1; then
        error "AWS CLI is not installed. Install it and try again."
        error "macOS: brew install awscli"
        error "Other platforms: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
        exit 1
    fi
}

# Check if LocalStack is running
check_localstack() {
    log "Checking LocalStack availability..."
    
    if ! curl -s -f "${LOCALSTACK_ENDPOINT}/_localstack/health" > /dev/null; then
        error "LocalStack is not running or not accessible at ${LOCALSTACK_ENDPOINT}"
        error "Please start LocalStack first with: docker-compose up -d"
        exit 1
    fi
    
    success "LocalStack is running"
}

# Create trust policy document for Spacelift
create_trust_policy() {
    log "Creating trust policy document..."
    
    cat > /tmp/spacelift-trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::324880187172:root"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": {
          "sts:ExternalId": "spacelift"
        }
      }
    }
  ]
}
EOF
    
    success "Trust policy document created"
}

# Create admin policy document
create_admin_policy() {
    log "Creating admin policy document..."
    
    cat > /tmp/spacelift-admin-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "*",
      "Resource": "*"
    }
  ]
}
EOF
    
    success "Admin policy document created"
}

# Create IAM role
create_iam_role() {
    log "Creating IAM role: ${ROLE_NAME}..."
    
    # Check if role already exists
    if aws iam get-role --role-name "${ROLE_NAME}" --endpoint-url "${LOCALSTACK_ENDPOINT}" --region "${AWS_REGION}" --no-cli-pager --no-cli-auto-prompt > /dev/null 2>&1; then
        warning "Role ${ROLE_NAME} already exists, updating trust policy..."
        aws iam update-assume-role-policy \
            --role-name "${ROLE_NAME}" \
            --policy-document file:///tmp/spacelift-trust-policy.json \
            --endpoint-url "${LOCALSTACK_ENDPOINT}" \
            --region "${AWS_REGION}" \
            --no-cli-pager --no-cli-auto-prompt
    else
        aws iam create-role \
            --role-name "${ROLE_NAME}" \
            --assume-role-policy-document file:///tmp/spacelift-trust-policy.json \
            --description "Admin role for Spacelift POC integration" \
            --endpoint-url "${LOCALSTACK_ENDPOINT}" \
            --region "${AWS_REGION}" \
            --no-cli-pager --no-cli-auto-prompt
    fi
    
    success "IAM role created/updated"
}

# Create and attach admin policy
create_and_attach_policy() {
    log "Creating and attaching admin policy..."
    
    # Check if policy already exists
    POLICY_ARN="arn:aws:iam::000000000000:policy/${POLICY_NAME}"
    if aws iam get-policy --policy-arn "${POLICY_ARN}" --endpoint-url "${LOCALSTACK_ENDPOINT}" --region "${AWS_REGION}" --no-cli-pager --no-cli-auto-prompt > /dev/null 2>&1; then
        warning "Policy ${POLICY_NAME} already exists, creating new version..."
        aws iam create-policy-version \
            --policy-arn "${POLICY_ARN}" \
            --policy-document file:///tmp/spacelift-admin-policy.json \
            --set-as-default \
            --endpoint-url "${LOCALSTACK_ENDPOINT}" \
            --region "${AWS_REGION}" \
            --no-cli-pager --no-cli-auto-prompt || true
    else
        aws iam create-policy \
            --policy-name "${POLICY_NAME}" \
            --policy-document file:///tmp/spacelift-admin-policy.json \
            --description "Admin policy for Spacelift POC" \
            --endpoint-url "${LOCALSTACK_ENDPOINT}" \
            --region "${AWS_REGION}" \
            --no-cli-pager --no-cli-auto-prompt
    fi
    
    # Attach policy to role
    aws iam attach-role-policy \
        --role-name "${ROLE_NAME}" \
        --policy-arn "${POLICY_ARN}" \
        --endpoint-url "${LOCALSTACK_ENDPOINT}" \
        --region "${AWS_REGION}" \
        --no-cli-pager --no-cli-auto-prompt
    
    success "Admin policy created and attached"
}

# Display role information
display_role_info() {
    log "Retrieving role information..."
    
    ROLE_ARN=$(aws iam get-role \
        --role-name "${ROLE_NAME}" \
        --endpoint-url "${LOCALSTACK_ENDPOINT}" \
        --region "${AWS_REGION}" \
        --query 'Role.Arn' \
        --output text \
        --no-cli-pager --no-cli-auto-prompt)
    
    echo ""
    echo "================================================"
    echo "LocalStack IAM Role Setup Complete"
    echo "================================================"
    echo "Role Name: ${ROLE_NAME}"
    echo "Role ARN:  ${ROLE_ARN}"
    echo "External ID: spacelift"
    echo ""
    echo "Use this role ARN in your Spacelift AWS integration"
    echo "================================================"
    echo ""
}

# Cleanup temporary files
cleanup() {
    rm -f /tmp/spacelift-trust-policy.json /tmp/spacelift-admin-policy.json
}

# Main execution
main() {
    log "Starting LocalStack IAM setup for Spacelift integration"

    check_aws_cli

    # Set AWS credentials for LocalStack
    export AWS_ACCESS_KEY_ID=test
    export AWS_SECRET_ACCESS_KEY=test
    export AWS_DEFAULT_REGION="${AWS_REGION}"
    
    # Configure AWS CLI to not use profiles and disable CLI pager
    unset AWS_PROFILE
    export AWS_CONFIG_FILE=""
    export AWS_SHARED_CREDENTIALS_FILE=""
    export AWS_PAGER=""
    
    check_localstack
    create_trust_policy
    create_admin_policy
    create_iam_role
    create_and_attach_policy
    display_role_info
    cleanup
    
    success "LocalStack IAM setup completed successfully!"
}

# Run main function
main "$@"