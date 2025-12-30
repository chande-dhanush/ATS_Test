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

Write-Host "🚀 Deploying $ProjectName-$Environment infrastructure..." -ForegroundColor Yellow

# Navigate to root to Zip
Set-Location (Join-Path (Split-Path $PSScriptRoot -Parent) "")
Write-Host "📦 Creating Lambda deployment package..." -ForegroundColor Gray
if (Test-Path "lambda-deployment.zip") { Remove-Item "lambda-deployment.zip" }
Compress-Archive -Path "main.py", "requirements.txt", "static" -DestinationPath "lambda-deployment.zip" -Force

# Navigate to terraform directory
Set-Location "terraform"

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

# Select or Create Workspace
$workspaces = terraform workspace list
if (-not ($workspaces | Select-String $Environment)) {
    terraform workspace new $Environment
} else {
    terraform workspace select $Environment
}

Write-Host "🔥 Running terraform apply..." -ForegroundColor Yellow
terraform apply `
  -var="project_name=ats-test" `
  -var="environment=$Environment" `
  -auto-approve

Write-Host "✅ Deployment Successful!" -ForegroundColor Green
