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

# Install VS Code extensions
Write-Host "Installing VS Code extensions..." -ForegroundColor Green

if (-not (Get-Command code -ErrorAction SilentlyContinue)) {
  Write-Host "⚠ 'code' command not found — skipping VS Code extensions. Make sure VS Code is installed and added to PATH." -ForegroundColor Yellow
}
else {
  $extensions = @(
    "42crunch.vscode-openapi",
    "angular.ng-template",
    "bradlc.vscode-tailwindcss",
    "danielgavin.ols",
    "docker.docker",
    "esbenp.prettier-vscode",
    "f-loat.jsonl-converter",
    "github.vscode-github-actions",
    "golang.go",
    "hashicorp.hcl",
    "hashicorp.terraform",
    "ms-azuretools.vscode-containers",
    "ms-azuretools.vscode-docker",
    "ms-python.autopep8",
    "ms-python.debugpy",
    "ms-python.python",
    "ms-python.vscode-pylance",
    "ms-python.vscode-python-envs",
    "ms-vscode-remote.remote-containers",
    "ms-vscode.live-server",
    "ms-vscode.makefile-tools",
    "redhat.vscode-yaml",
    "timheuer.awesome-copilot"
  )

  foreach ($ext in $extensions) {
    Write-Host "Installing $ext..." -ForegroundColor Cyan
    code --install-extension $ext --force
  }

  Write-Host "✓ VS Code extensions installed" -ForegroundColor Green
}

Write-Host "Installing Go version manager (gvm)..." -ForegroundColor Green

[Net.ServicePointManager]::SecurityProtocol = "tls12"
Invoke-WebRequest -URI https://github.com/andrewkroh/gvm/releases/download/v0.6.0/gvm-windows-amd64.exe -Outfile C:\Windows\System32\gvm.exe
gvm --format=powershell 1.26.1 | Invoke-Expression
go version