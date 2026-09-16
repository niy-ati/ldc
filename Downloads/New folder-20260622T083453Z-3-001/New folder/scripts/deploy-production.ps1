# Production deploy for Slush validation on stable HTTPS.
# Requires: npx netlify-cli login OR $env:NETLIFY_AUTH_TOKEN

$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)

Write-Host "Building production bundle (dist-release)..." -ForegroundColor Cyan
npm run build:release
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$dist = "packages/command-center/dist-release"
if (-not (Test-Path $dist)) {
  Write-Error "Build output missing: $dist"
}

if (-not $env:NETLIFY_AUTH_TOKEN) {
  $status = npx netlify-cli status 2>&1 | Out-String
  if ($status -match "Not logged in") {
    Write-Host ""
    Write-Host "Not logged in to Netlify. Run:" -ForegroundColor Yellow
    Write-Host "  npx netlify-cli login"
    Write-Host "  npm run deploy:netlify"
    Write-Host ""
    Write-Host "Or set NETLIFY_AUTH_TOKEN + optional NETLIFY_SITE_ID for CI." -ForegroundColor Yellow
    exit 1
  }
}

Write-Host "Deploying to Netlify production..." -ForegroundColor Cyan
$siteArg = @()
if ($env:NETLIFY_SITE_ID) {
  $siteArg = @("--site", $env:NETLIFY_SITE_ID)
}

npx netlify-cli deploy --prod --dir=$dist @siteArg
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ""
Write-Host "Deploy complete. Run Slush test per docs/SLUSH_VALIDATION.md" -ForegroundColor Green
