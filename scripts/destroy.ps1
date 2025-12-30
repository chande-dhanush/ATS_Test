param(
    [Parameter(Mandatory=$true)]
    [string]$Environment,
    [string]$ProjectName = "ats-test"
)

# Validate environment parameter
if ($Environment -notmatch '^(dev|test|prod)$') {
    Write-Host "Error: Invalid environment '$Environment'" -ForegroundColor Red
    Write-Host "Available environments: dev, test, prod" -ForegroundColor Yellow
    exit 1
}

Write-Host "🗑️ Preparing to destroy $ProjectName-$Environment infrastructure..." -ForegroundColor Yellow

# Navigate to terraform directory
Set-Location (Join-Path (Split-Path $PSScriptRoot -Parent) "terraform")

# Get AWS Account ID for backend configuration
$awsAccountId = aws sts get-caller-identity --query Account --output text
$awsRegion = if ($env:DEFAULT_AWS_REGION) { $env:DEFAULT_AWS_REGION } else { "ap-south-1" }

# Initialize terraform with S3 backend
Write-Host "🔧 Initializing Terraform with S3 backend..." -ForegroundColor Yellow
terraform init -input=false `
  -backend-config="bucket=ats-test-terraform-state-$awsAccountId" `
  -backend-config="key=$Environment/terraform.tfstate" `
  -backend-config="region=$awsRegion" `
  -backend-config="dynamodb_table=ats-test-terraform-locks" `
  -backend-config="encrypt=true"

# Check if workspace exists
$workspaces = terraform workspace list
if (-not ($workspaces | Select-String $Environment)) {
    Write-Host "Error: Workspace '$Environment' does not exist" -ForegroundColor Red
    Write-Host "Available workspaces:" -ForegroundColor Yellow
    terraform workspace list
    exit 1
}

# Select the workspace
terraform workspace select $Environment

Write-Host "📦 Emptying S3 buckets..." -ForegroundColor Yellow

# Define bucket names 
# Note carefully: ensure this matches creating logic (underscores or hyphens)
# If main.tf used local.name_prefix = ats_test-dev, then bucket is ats_test-dev-frontend... ILLEGAL
# I will assume I fix creation to use hyphens `ats-test`.
$FrontendBucket = "$ProjectName-$Environment-frontend-$awsAccountId"
$MemoryBucket = "$ProjectName-$Environment-memory-$awsAccountId"

# Empty frontend bucket if it exists
try {
    aws s3 ls "s3://$FrontendBucket" 2>$null | Out-Null
    Write-Host "  Emptying $FrontendBucket using AWS CLI..." -ForegroundColor Gray
    aws s3 rm "s3://$FrontendBucket" --recursive
} catch {
    Write-Host "  $FrontendBucket not found or already empty" -ForegroundColor Gray
}

# Empty memory bucket if it exists
try {
    aws s3 ls "s3://$MemoryBucket" 2>$null | Out-Null
    Write-Host "  Emptying $MemoryBucket using AWS CLI..." -ForegroundColor Gray
    aws s3 rm "s3://$MemoryBucket" --recursive
} catch {
    Write-Host "  $MemoryBucket not found or already empty" -ForegroundColor Gray
}

Write-Host "🔥 Running terraform destroy..." -ForegroundColor Yellow

# Create a dummy lambda zip if it doesn't exist
if (-not (Test-Path "..\lambda-deployment.zip")) {
    Write-Host "Creating dummy lambda package for destroy operation..." -ForegroundColor Gray
    Set-Content -Path "dummy.txt" -Value "dummy"
    Compress-Archive -Path "dummy.txt" -DestinationPath "..\lambda-deployment.zip" -Force
    Remove-Item "dummy.txt"
}

# Run terraform destroy with auto-approve
terraform destroy -var="project_name=ats_test" -var="environment=$Environment" -auto-approve


Write-Host "Infrastructure for $Environment has been destroyed!" -ForegroundColor Green
Write-Host ""
Write-Host "  To remove the workspace completely, run:" -ForegroundColor Cyan
Write-Host "   terraform workspace select default" -ForegroundColor White
Write-Host "   terraform workspace delete $Environment" -ForegroundColor White
