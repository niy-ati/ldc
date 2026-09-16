# Build and deploy TITAN Command Center to Netlify for Slush HTTPS validation.
param(
  [switch]$SkipBuild,
  [switch]$Anonymous
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

if (-not $SkipBuild) {
  Write-Host "Building production bundle..."
  npm run build
}

$Dist = Join-Path $Root 'packages\command-center\dist'
if (-not (Test-Path $Dist)) {
  throw "Missing dist at $Dist"
}

Write-Host "Deploying from $Dist"

$netlifyArgs = @('netlify-cli', 'deploy', '--prod', '--dir', $Dist, '--message', 'TITAN Slush wallet validation')
if ($Anonymous) {
  $netlifyArgs += '--allow-anonymous'
}

if ($env:NETLIFY_AUTH_TOKEN) {
  Write-Host 'Using NETLIFY_AUTH_TOKEN'
} elseif (-not $Anonymous) {
  Write-Host 'NETLIFY_AUTH_TOKEN not set. Use -Anonymous for Netlify Drop, or run: netlify login'
}

& npx @netlifyArgs

Write-Host ''
Write-Host 'Slush validation paths:'
Write-Host '  /wallet-navi-pattern.html'
Write-Host '  /wallet-raw.html'
Write-Host '  /demo'
