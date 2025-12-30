# =============================================================================
# ATS Resume Analyzer - Deploy Script (Windows PowerShell)
# Builds and deploys the application to AWS
# =============================================================================

param(
    [ValidateSet("dev", "test", "prod")]
    [string]$Environment = "dev",
    
    [string]$ProjectName = "ats_test"
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "=============================================" -ForegroundColor Green
Write-Host " ATS Resume Analyzer - Deploy to AWS" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green
Write-Host ""
Write-Host "Environment: $Environment" -ForegroundColor Cyan
Write-Host "Project:     $ProjectName" -ForegroundColor Cyan
Write-Host ""

# Get project root
$projectRoot = Split-Path $PSScriptRoot -Parent
Set-Location $projectRoot

# Step 1: Build Docker Image
Write-Host "[1/5] Building Docker image..." -ForegroundColor Yellow
docker build -t "${ProjectName}-${Environment}:latest" .

if ($LASTEXITCODE -ne 0) {
    Write-Host "Docker build failed!" -ForegroundColor Red
    exit 1
}
Write-Host "Docker image built successfully!" -ForegroundColor Green

# Step 2: Initialize Terraform
Write-Host ""
Write-Host "[2/5] Initializing Terraform..." -ForegroundColor Yellow
Set-Location terraform
terraform init -input=false

# Step 3: Create/Select Workspace
Write-Host ""
Write-Host "[3/5] Setting up workspace..." -ForegroundColor Yellow
$workspaces = terraform workspace list
if (-not ($workspaces -match $Environment)) {
    Write-Host "Creating workspace: $Environment" -ForegroundColor Cyan
    terraform workspace new $Environment
} else {
    terraform workspace select $Environment
}

# Step 4: Apply Terraform
Write-Host ""
Write-Host "[4/5] Applying Terraform changes..." -ForegroundColor Yellow
terraform apply `
    -var="project_name=$ProjectName" `
    -var="environment=$Environment" `
    -auto-approve

if ($LASTEXITCODE -ne 0) {
    Write-Host "Terraform apply failed!" -ForegroundColor Red
    exit 1
}

# Step 5: Push Docker Image to ECR
Write-Host ""
Write-Host "[5/5] Pushing Docker image to ECR..." -ForegroundColor Yellow

$ecrUrl = terraform output -raw ecr_repository_url
$awsRegion = terraform output -raw aws_region

# Login to ECR
aws ecr get-login-password --region $awsRegion | docker login --username AWS --password-stdin $ecrUrl.Split('/')[0]

# Tag and push
docker tag "${ProjectName}-${Environment}:latest" "${ecrUrl}:latest"
docker push "${ecrUrl}:latest"

# Update Lambda
$lambdaName = terraform output -raw lambda_function_name
aws lambda update-function-code `
    --function-name $lambdaName `
    --image-uri "${ecrUrl}:latest" `
    --region $awsRegion | Out-Null

Write-Host ""
Write-Host "=============================================" -ForegroundColor Green
Write-Host " Deployment Complete!" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green
Write-Host ""
Write-Host "API Gateway URL: $(terraform output -raw api_gateway_url)" -ForegroundColor Cyan
Write-Host "Lambda URL:      $(terraform output -raw lambda_function_url)" -ForegroundColor Cyan
Write-Host ""

Set-Location $projectRoot
