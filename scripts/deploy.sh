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

echo "🚀 Deploying ${PROJECT_NAME}-${ENVIRONMENT} infrastructure..."

# Create Zip package
echo "📦 Creating Lambda deployment package..."
# Ensure we are in root for zipping
cd "$(dirname "$0")/.."
zip -r lambda-deployment.zip main.py requirements.txt static/ -x "**/.*" "**/__pycache__/*"

# Navigate to terraform directory
cd terraform

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

# Select or Create Workspace
if terraform workspace list | grep -q "$ENVIRONMENT"; then
    terraform workspace select "$ENVIRONMENT"
else
    terraform workspace new "$ENVIRONMENT"
fi

# Apply Terraform
echo "🔥 Running terraform apply..."
terraform apply \
  -var="project_name=ats-test" \
  -var="environment=$ENVIRONMENT" \
  -auto-approve

# Get the frontend bucket name from terraform output
FRONTEND_BUCKET=$(terraform output -raw s3_frontend_bucket)

# Upload frontend files to S3
echo "📤 Uploading frontend files to S3..."
cd ..
aws s3 sync static/ "s3://${FRONTEND_BUCKET}/" --delete

echo "✅ Deployment Successful!"
