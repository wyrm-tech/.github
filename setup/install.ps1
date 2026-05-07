# Install Basecamp and Clerk CLIs for Windows
# Run with: powershell -ExecutionPolicy Bypass -File install.ps1

param(
  [switch]$Force = $false
)

$ErrorActionPreference = "Stop"

function Refresh-Path {
  $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
  $userPath = [Environment]::GetEnvironmentVariable("Path", "User")

  if ([string]::IsNullOrWhiteSpace($machinePath)) {
    $env:Path = $userPath
  }
  elseif ([string]::IsNullOrWhiteSpace($userPath)) {
    $env:Path = $machinePath
  }
  else {
    $env:Path = "$machinePath;$userPath"
  }
}

function Install-LatestNodeWithNvm {
  if (-not (Get-Command nvm -ErrorAction SilentlyContinue)) {
    Write-Host "✗ nvm not found in PATH. Ensure nvm-windows is installed." -ForegroundColor Red
    return $false
  }

  try {
    Write-Host "Installing latest Node.js with nvm..." -ForegroundColor Cyan
    nvm install latest

    Write-Host "Using latest Node.js with nvm..." -ForegroundColor Cyan
    nvm use latest

    # Ensure npm/node shims from the selected nvm version are picked up.
    Refresh-Path
    return $true
  }
  catch {
    Write-Host "✗ Failed to install/use latest Node.js with nvm: $_" -ForegroundColor Red
    return $false
  }
}

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

Refresh-Path

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
  Write-Host "Refreshing PATH for current PowerShell session..." -ForegroundColor Cyan

  Write-Host "Installing Clerk CLI..." -ForegroundColor Cyan
  try {
    $nodeReady = Install-LatestNodeWithNvm

    if ($nodeReady -and (Get-Command npm -ErrorAction SilentlyContinue)) {
      Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
      npm install -g clerk
    }
    else {
      Write-Host "✗ npm not found after nvm setup. Install Node.js manually or download Clerk CLI from https://dashboard.clerk.com" -ForegroundColor Red
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

if (-not (Get-Command gvm -ErrorAction SilentlyContinue)) {
  Write-Host "Installing Go version manager (gvm)..." -ForegroundColor Green
  [Net.ServicePointManager]::SecurityProtocol = "tls12"
  Invoke-WebRequest -URI https://github.com/andrewkroh/gvm/releases/download/v0.6.0/gvm-windows-amd64.exe -Outfile C:\Windows\System32\gvm.exe
  Refresh-Path
}
else {
  Write-Host "✓ gvm already installed" -ForegroundColor Green
}

if (-not (Get-Command go -ErrorAction SilentlyContinue)) {
  Write-Host "Fetching latest stable Go version..." -ForegroundColor Cyan
  $latestGo = ((Invoke-RestMethod -Uri "https://go.dev/dl/?mode=json") | Select-Object -First 1).version -replace '^go', ''
  Write-Host "Installing Go $latestGo..." -ForegroundColor Cyan
  gvm --format=powershell $latestGo | Invoke-Expression
}
else {
  Write-Host "✓ Go already installed" -ForegroundColor Green
  go version
}

if (Get-Command go -ErrorAction SilentlyContinue) {
  $goRoot = go env GOROOT
  if (-not [string]::IsNullOrWhiteSpace($goRoot)) {
    $goBin = Join-Path $goRoot "bin"
    $env:GOROOT = $goRoot
    [Environment]::SetEnvironmentVariable("GOROOT", $goRoot, "User")
    Write-Host "✓ GOROOT set to $goRoot" -ForegroundColor Green

    $currentUserPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $userPathEntries = @()
    if (-not [string]::IsNullOrWhiteSpace($currentUserPath)) {
      $userPathEntries = $currentUserPath -split ';'
    }

    if ($userPathEntries -notcontains $goBin) {
      if ([string]::IsNullOrWhiteSpace($currentUserPath)) {
        $updatedUserPath = $goBin
      }
      else {
        $updatedUserPath = "$currentUserPath;$goBin"
      }

      [Environment]::SetEnvironmentVariable("Path", $updatedUserPath, "User")
      Write-Host "✓ Added $goBin to user PATH" -ForegroundColor Green
    }
    else {
      Write-Host "✓ $goBin already in user PATH" -ForegroundColor Green
    }

    if (($env:Path -split ';') -notcontains $goBin) {
      $env:Path = "$env:Path;$goBin"
      Write-Host "✓ Added $goBin to current session PATH" -ForegroundColor Green
    }
  }
  else {
    Write-Host "⚠ Could not determine GOROOT from 'go env GOROOT'" -ForegroundColor Yellow
  }
}
else {
  Write-Host "⚠ Skipping GOROOT setup because 'go' is not available" -ForegroundColor Yellow
}

Write-Host "Installing Go tools..." -ForegroundColor Green
go install golang.org/x/tools/gopls@latest
go install honnef.co/go/tools/cmd/staticcheck@latest
Write-Host "✓ Go tools installed" -ForegroundColor Green