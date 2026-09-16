# Deploy TITAN to Vercel from repo root (remote build — no local dist upload).
$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
Set-Location $root

Write-Host "Checking Vercel auth..." -ForegroundColor Cyan
$who = npx vercel whoami 2>&1 | Out-String
if ($who -match "No existing credentials|not logged in|Starting login") {
  Write-Host "Run: npx vercel login" -ForegroundColor Yellow
  exit 1
}
Write-Host $who.Trim()

if (-not (Test-Path ".vercel\project.json")) {
  Write-Host ""
  Write-Host "Link project from repo root first:" -ForegroundColor Yellow
  Write-Host '  cd "c:\Users\niyat\New folder"' -ForegroundColor Yellow
  Write-Host "  npx vercel link" -ForegroundColor Yellow
  Write-Host "  Name: titan-mandateos  |  Customize settings: No" -ForegroundColor Yellow
  exit 1
}

Write-Host "Deploying (remote build on Vercel)..." -ForegroundColor Cyan
npx vercel --prod --yes
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ""
Write-Host "Production URL printed above - use it for Slush testing." -ForegroundColor Green
