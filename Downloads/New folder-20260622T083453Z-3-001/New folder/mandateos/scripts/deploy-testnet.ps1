# MandateOS Testnet Deployment Script
# Requires: Sui CLI installed and configured for testnet

$ErrorActionPreference = "Stop"

Write-Host "MandateOS — Deploying to Sui Testnet" -ForegroundColor Cyan

# Verify sui CLI
if (-not (Get-Command sui -ErrorAction SilentlyContinue)) {
    Write-Host "Sui CLI not found. Install from: https://docs.sui.io/guides/developer/getting-started/sui-install" -ForegroundColor Red
    exit 1
}

# Switch to testnet if needed
$activeEnv = sui client active-env 2>&1
if ($activeEnv -notmatch "testnet") {
    Write-Host "Switching to testnet environment..."
    sui client new-env --alias testnet --rpc https://fullnode.testnet.sui.io:443 2>$null
    sui client switch --env testnet
}

# Build
Write-Host "`nBuilding package..." -ForegroundColor Yellow
Push-Location $PSScriptRoot\..
sui move build
if ($LASTEXITCODE -ne 0) { Pop-Location; exit $LASTEXITCODE }

# Test
Write-Host "`nRunning tests..." -ForegroundColor Yellow
sui move test
if ($LASTEXITCODE -ne 0) { Pop-Location; exit $LASTEXITCODE }

# Publish
Write-Host "`nPublishing to testnet..." -ForegroundColor Yellow
sui client publish --gas-budget 200000000 -e testnet
Pop-Location

Write-Host "`nDeployment complete." -ForegroundColor Green
