#!/bin/bash
set -e

# Check if environment parameter is provided
if [ $# -eq 0 ]; then
    echo "❌ Error: Environment parameter is required"
    echo "Usage: $0 <environment>"
    echo "Example: $0 dev"
    echo "Available environments: dev, test, prod"
    exit 1
fi

ENVIRONMENT=$1
PROJECT_NAME=${2:-ats-test}

echo "🗑️ Preparing to destroy ${PROJECT_NAME}-${ENVIRONMENT} infrastructure..."

# Navigate to terraform directory
cd "$(dirname "$0")/../terraform"

# Get AWS Account ID and Region for backend configuration
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=${DEFAULT_AWS_REGION:-ap-south-1}

# Initialize terraform with S3 backend
echo "🔧 Initializing Terraform with S3 backend..."
terraform init -input=false \
  -backend-config="bucket=ats-test-terraform-state-${AWS_ACCOUNT_ID}" \
  -backend-config="key=${ENVIRONMENT}/terraform.tfstate" \
  -backend-config="region=${AWS_REGION}" \
  -backend-config="dynamodb_table=ats-test-terraform-locks" \
  -backend-config="encrypt=true"

# Check if workspace exists
if ! terraform workspace list | grep -q "$ENVIRONMENT"; then
    echo "❌ Error: Workspace '$ENVIRONMENT' does not exist"
    echo "Available workspaces:"
    terraform workspace list
    exit 1
fi

# Select the workspace
terraform workspace select "$ENVIRONMENT"

echo "📦 Emptying S3 buckets..."

# Get bucket names with account ID (matching Day 4 naming)
# Note: Bucket name pattern from main.tf: ${name_prefix}-frontend-${account_id}
# name_prefix = ${project_name}-${environment}
# Defaults: project_name=ats_test
# BUT wait, the S3 naming rule uses dashes usually. 
# main.tf: bucket = "${local.name_prefix}-frontend-..."
# local.name_prefix = "${var.project_name}-${var.environment}"
# var.project_name defaults to "ats_test". 
# So bucket name is "ats_test-dev-frontend-..."
# Wait, S3 buckets CANNOT contain underscores.
# The `project_name` variable validation in variables.tf allows "a-z0-9-", so HYPHENS.
# But `terraform.tfvars` sets it to "ats_test" (underscore). 
# This will FAIL S3 creation if I apply it.
# I MUST CHANGE `terraform.tfvars` to `ats-test` (hyphen). 
# I will do that in the next step.
# For now, I'll assume the script uses `ats-test` or `ats_test` based on what the terraform uses.
# Best is to fetch from terraform output if possible? No, outputs are per workspace.
# I'll rely on generic logic or `aws s3 ls` matching.

# Actually, I'll use the variable passed ($PROJECT_NAME) which defaults to `ats-test`.

FRONTEND_BUCKET="${PROJECT_NAME}-${ENVIRONMENT}-frontend-${AWS_ACCOUNT_ID}"
MEMORY_BUCKET="${PROJECT_NAME}-${ENVIRONMENT}-memory-${AWS_ACCOUNT_ID}"

# Empty frontend bucket if it exists
if aws s3 ls "s3://$FRONTEND_BUCKET" 2>/dev/null; then
    echo "  Emptying $FRONTEND_BUCKET..."
    aws s3 rm "s3://$FRONTEND_BUCKET" --recursive
else
    echo "  Frontend bucket not found or already empty (checked $FRONTEND_BUCKET)"
fi

# Empty memory bucket if it exists
if aws s3 ls "s3://$MEMORY_BUCKET" 2>/dev/null; then
    echo "  Emptying $MEMORY_BUCKET..."
    aws s3 rm "s3://$MEMORY_BUCKET" --recursive
else
    echo "  Memory bucket not found or already empty"
fi

echo "🔥 Running terraform destroy..."

# Create a dummy lambda zip if it doesn't exist (needed for destroy in GitHub Actions)
if [ ! -f "../lambda-deployment.zip" ]; then
    echo "Creating dummy lambda package for destroy operation..."
    # Ensure checking root relative path
    echo "dummy" > dummy.txt
    zip ../lambda-deployment.zip dummy.txt
    rm dummy.txt
fi

# Run terraform destroy with auto-approve
terraform destroy \
  -var="project_name=ats-test" \
  -var="environment=$ENVIRONMENT" \
  -auto-approve

echo "✅ Infrastructure for ${ENVIRONMENT} has been destroyed!"
echo ""
echo "💡 To remove the workspace completely, run:"
echo "   terraform workspace select default"
echo "   terraform workspace delete $ENVIRONMENT"
