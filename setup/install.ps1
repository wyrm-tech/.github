# Install Basecamp and Clerk CLIs for Windows
# Run with: powershell -ExecutionPolicy Bypass -File install.ps1

param(
  [switch]$Force = $false
)

$ErrorActionPreference = "Stop"

Write-Host "Installing dependencies..." -ForegroundColor Green

# Install winget packages
$wingetUrl = "https://raw.githubusercontent.com/wyrm-tech/.github/refs/heads/main/setup/winget.json"
$wingetJson = Join-Path $env:TEMP "winget.json"

Write-Host "Downloading winget.json from GitHub..." -ForegroundColor Cyan
try {
  Invoke-WebRequest -Uri $wingetUrl -OutFile $wingetJson
}
catch {
  Write-Host "✗ Failed to download winget.json: $_" -ForegroundColor Red
  exit 1
}

Write-Host "Installing packages from winget.json..." -ForegroundColor Cyan
winget import --import-file $wingetJson --accept-package-agreements --accept-source-agreements

Write-Host "Installing Basecamp and Clerk CLIs..." -ForegroundColor Green

# Install Basecamp CLI
if (-not (Get-Command basecamp -ErrorAction SilentlyContinue) -or $Force) {
  Write-Host "Installing Basecamp CLI..." -ForegroundColor Cyan
  try {
    Invoke-RestMethod -Uri https://raw.githubusercontent.com/basecamp/basecamp-cli/main/scripts/install.ps1 | Invoke-Expression
  }
  catch {
    Write-Host "✗ Failed to install Basecamp CLI: $_" -ForegroundColor Red
    exit 1
  }
}
else {
  Write-Host "✓ Basecamp CLI already installed" -ForegroundColor Green
}

# Install Clerk CLI
if (-not (Get-Command clerk -ErrorAction SilentlyContinue) -or $Force) {
  Write-Host "Installing Clerk CLI..." -ForegroundColor Cyan
  try {
    if (Get-Command npm -ErrorAction SilentlyContinue) {
      npm install -g @clerk/cli
    }
    else {
      Write-Host "✗ npm not found. Install Node.js or download Clerk CLI from https://dashboard.clerk.com" -ForegroundColor Red
    }
  }
  catch {
    Write-Host "✗ Failed to install Clerk CLI: $_" -ForegroundColor Red
  }
}
else {
  Write-Host "✓ Clerk CLI already installed" -ForegroundColor Green
}

Write-Host "✓ CLI installation complete" -ForegroundColor Green
