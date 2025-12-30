#!/bin/bash
# =============================================================================
# ATS Resume Analyzer - Destroy Script (Mac/Linux)
# Destroys all AWS resources for a given environment
# =============================================================================

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
PROJECT_NAME=${2:-ats_test}

echo "🗑️  Preparing to destroy ${PROJECT_NAME}-${ENVIRONMENT} infrastructure..."
echo ""
echo "⚠️  WARNING: This will permanently delete all resources!"
read -p "Are you sure? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "❌ Cancelled."
    exit 0
fi

# Navigate to terraform directory
cd "$(dirname "$0")/../terraform"

# Initialize if needed
terraform init -input=false

# Check if workspace exists
if ! terraform workspace list | grep -q "$ENVIRONMENT"; then
    echo "❌ Error: Workspace '$ENVIRONMENT' does not exist"
    echo "Available workspaces:"
    terraform workspace list
    exit 1
fi

# Select the workspace
terraform workspace select "$ENVIRONMENT"

echo ""
echo "🔥 Running terraform destroy..."

# Run terraform destroy
terraform destroy \
    -var="project_name=$PROJECT_NAME" \
    -var="environment=$ENVIRONMENT" \
    -auto-approve

echo ""
echo "✅ Infrastructure for ${PROJECT_NAME}-${ENVIRONMENT} has been destroyed!"
echo ""
echo "💡 To remove the workspace completely, run:"
echo "   cd terraform"
echo "   terraform workspace select default"
echo "   terraform workspace delete $ENVIRONMENT"
