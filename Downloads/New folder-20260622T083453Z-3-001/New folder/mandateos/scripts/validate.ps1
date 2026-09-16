# MandateOS — Compile and test validation (no deploy)
# Requires: Sui CLI — https://docs.sui.io/guides/developer/getting-started/sui-install

$ErrorActionPreference = "Stop"

Write-Host "MandateOS — Compile Validation" -ForegroundColor Cyan

if (-not (Get-Command sui -ErrorAction SilentlyContinue)) {
    Write-Host "Sui CLI not found. Install from:" -ForegroundColor Red
    Write-Host "  https://docs.sui.io/guides/developer/getting-started/sui-install" -ForegroundColor Yellow
    exit 1
}

Push-Location $PSScriptRoot\..

Write-Host "`n[sui move build]" -ForegroundColor Yellow
sui move build
if ($LASTEXITCODE -ne 0) { Pop-Location; exit $LASTEXITCODE }

Write-Host "`n[sui move test]" -ForegroundColor Yellow
sui move test
$testExit = $LASTEXITCODE

Pop-Location

if ($testExit -ne 0) { exit $testExit }

Write-Host "`nValidation passed." -ForegroundColor Green
