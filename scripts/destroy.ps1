# =============================================================================
# ATS Resume Analyzer - Destroy Script (Windows PowerShell)
# Destroys all AWS resources for a given environment
# =============================================================================

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("dev", "test", "prod")]
    [string]$Environment,
    
    [string]$ProjectName = "ats_test",
    
    [switch]$Force  # Skip confirmation
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "=============================================" -ForegroundColor Yellow
Write-Host " ATS Resume Analyzer - Destroy Infrastructure" -ForegroundColor Yellow
Write-Host "=============================================" -ForegroundColor Yellow
Write-Host ""
Write-Host "Environment: $Environment" -ForegroundColor Cyan
Write-Host "Project:     $ProjectName" -ForegroundColor Cyan
Write-Host ""

# Confirmation
if (-not $Force) {
    Write-Host "WARNING: This will permanently delete all AWS resources!" -ForegroundColor Red
    Write-Host ""
    $confirm = Read-Host "Type '$Environment' to confirm destruction"
    
    if ($confirm -ne $Environment) {
        Write-Host "Cancelled - confirmation did not match." -ForegroundColor Yellow
        exit 0
    }
}

# Navigate to terraform directory
$terraformDir = Join-Path (Split-Path $PSScriptRoot -Parent) "terraform"
Set-Location $terraformDir

Write-Host ""
Write-Host "Initializing Terraform..." -ForegroundColor Yellow
terraform init -input=false

# Check if workspace exists
$workspaces = terraform workspace list
if (-not ($workspaces -match $Environment)) {
    Write-Host "Error: Workspace '$Environment' does not exist" -ForegroundColor Red
    Write-Host "Available workspaces:" -ForegroundColor Yellow
    terraform workspace list
    exit 1
}

# Select workspace
terraform workspace select $Environment

Write-Host ""
Write-Host "Running terraform destroy..." -ForegroundColor Yellow
Write-Host ""

# Get AWS region from variables
$awsRegion = "ap-south-2"

# Destroy
terraform destroy `
    -var="project_name=$ProjectName" `
    -var="environment=$Environment" `
    -var="aws_region=$awsRegion" `
    -auto-approve

Write-Host ""
Write-Host "=============================================" -ForegroundColor Green
Write-Host " Infrastructure destroyed successfully!" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green
Write-Host ""
Write-Host "To remove the workspace completely:" -ForegroundColor Cyan
Write-Host "  cd terraform" -ForegroundColor White
Write-Host "  terraform workspace select default" -ForegroundColor White
Write-Host "  terraform workspace delete $Environment" -ForegroundColor White
