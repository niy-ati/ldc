# Push .env.production vars to Vercel project (run once after vercel link).
$ErrorActionPreference = "Stop"
Push-Location (Split-Path $PSScriptRoot -Parent)

$envFile = "packages\command-center\.env.production"
if (-not (Test-Path $envFile)) { throw "Missing $envFile" }

Get-Content $envFile | ForEach-Object {
  if ($_ -match '^\s*#' -or $_ -match '^\s*$') { return }
  $parts = $_ -split '=', 2
  if ($parts.Length -lt 2) { return }
  $name = $parts[0].Trim()
  $value = $parts[1].Trim()
  foreach ($target in @('production', 'preview', 'development')) {
    Write-Host "Setting $name ($target) ..." -ForegroundColor Cyan
    $value | npx vercel env add $name $target --force 2>&1 | Out-Null
  }
}

Pop-Location
Write-Host "Environment variables synced to Vercel (production, preview, development)." -ForegroundColor Green
