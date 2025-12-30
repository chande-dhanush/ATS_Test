# ============================================
# ATS Resume Analyzer - Auto Setup and Run Script
# ============================================
# This script handles everything automatically:
# 1. Checks if Python virtual environment exists
# 2. Creates venv if missing
# 3. Installs all dependencies if fresh install
# 4. Creates .env file if missing
# 5. Starts the server
# ============================================

$ErrorActionPreference = "Stop"

# Colors for pretty output
function Write-Header { 
    param($text) 
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host $text -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan 
}

function Write-Step { 
    param($text) 
    Write-Host "[*] $text" -ForegroundColor Yellow 
}

function Write-Success { 
    param($text) 
    Write-Host "[OK] $text" -ForegroundColor Green 
}

function Write-Err { 
    param($text) 
    Write-Host "[X] $text" -ForegroundColor Red 
}

function Write-Info { 
    param($text) 
    Write-Host "[i] $text" -ForegroundColor Magenta 
}

Write-Header "ATS Resume Analyzer - Setup"

# Get script directory (where this script is located)
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptDir

$venvPath = ".\.venv"
$activateScript = "$venvPath\Scripts\Activate.ps1"
$pipPath = "$venvPath\Scripts\pip.exe"
$pythonPath = "$venvPath\Scripts\python.exe"
$envFile = ".\.env"
$envExample = ".\.env.example"
$freshInstall = $false

# ============================================
# Step 1: Check for Python
# ============================================
Write-Step "Checking for Python installation..."

try {
    $pythonVersion = python --version 2>&1
    Write-Success "Found $pythonVersion"
} catch {
    Write-Err "Python not found! Please install Python 3.10+ from https://python.org"
    Read-Host "Press Enter to exit"
    exit 1
}

# ============================================
# Step 2: Check/Create Virtual Environment
# ============================================
Write-Step "Checking virtual environment..."

if (Test-Path $venvPath) {
    Write-Success "Virtual environment exists"
} else {
    Write-Info "Creating virtual environment..."
    python -m venv .venv
    if ($LASTEXITCODE -ne 0) {
        Write-Err "Failed to create virtual environment"
        Read-Host "Press Enter to exit"
        exit 1
    }
    Write-Success "Virtual environment created"
    $freshInstall = $true
}

# ============================================
# Step 3: Activate Virtual Environment
# ============================================
Write-Step "Activating virtual environment..."

try {
    . $activateScript
    Write-Success "Virtual environment activated"
} catch {
    Write-Err "Failed to activate virtual environment"
    Write-Info "You may need to run: Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser"
    Read-Host "Press Enter to exit"
    exit 1
}

# ============================================
# Step 4: Install Dependencies (if fresh install)
# ============================================
if ($freshInstall) {
    Write-Step "Installing dependencies (first-time setup)..."
    & $pipPath install --upgrade pip | Out-Null
    & $pipPath install -r requirements.txt
    if ($LASTEXITCODE -ne 0) {
        Write-Err "Failed to install dependencies"
        Read-Host "Press Enter to exit"
        exit 1
    }
    Write-Success "All dependencies installed"
} else {
    Write-Success "Dependencies already installed (not a fresh install)"
}

# ============================================
# Step 5: Check/Create .env File
# ============================================
Write-Step "Checking .env configuration..."

if (Test-Path $envFile) {
    $envContent = Get-Content $envFile -Raw
    if ($envContent -match "your_groq_api_key_here" -or $envContent -match "GROQ_API_KEY=$" -or [string]::IsNullOrWhiteSpace($envContent)) {
        Write-Info ".env file exists but API key is not set!"
        Write-Host ""
        Write-Host "  Please get your Groq API key from: https://console.groq.com/keys" -ForegroundColor White
        Write-Host ""
        $apiKey = Read-Host "  Enter your Groq API key (or press Enter to skip)"
        
        if (-not [string]::IsNullOrWhiteSpace($apiKey)) {
            "GROQ_API_KEY=$apiKey" | Set-Content $envFile
            Write-Success "API key saved to .env"
        } else {
            Write-Info "Skipped - you can add it later to .env file"
        }
    } else {
        Write-Success ".env file configured"
    }
} else {
    Write-Info ".env file not found, creating..."
    Write-Host ""
    Write-Host "  Please get your Groq API key from: https://console.groq.com/keys" -ForegroundColor White
    Write-Host ""
    $apiKey = Read-Host "  Enter your Groq API key (or press Enter to skip)"
    
    if (-not [string]::IsNullOrWhiteSpace($apiKey)) {
        "GROQ_API_KEY=$apiKey" | Set-Content $envFile
        Write-Success "Created .env with API key"
    } else {
        "GROQ_API_KEY=your_groq_api_key_here" | Set-Content $envFile
        Write-Info "Created .env template - please add your API key later"
    }
}

# ============================================
# Step 6: Start the Server
# ============================================
Write-Header "Starting ATS Resume Analyzer"

Write-Host ""
Write-Host "  Open your browser to: " -NoNewline
Write-Host "http://127.0.0.1:8000" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Press Ctrl+C to stop the server" -ForegroundColor DarkGray
Write-Host ""

# Start the server
& $pythonPath -m uvicorn main:app --reload --port 8000

# When server stops
Write-Host ""
Write-Info "Server stopped"
Read-Host "Press Enter to exit"
