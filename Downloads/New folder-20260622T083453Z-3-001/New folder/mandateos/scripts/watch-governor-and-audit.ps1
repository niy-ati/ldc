# Poll governor balance; run full reality audit when upgrade gas threshold is met.
param(
  [int]$IntervalSeconds = 30,
  [bigint]$MinMist = 646000000
)

$ErrorActionPreference = "Stop"
$Root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
Set-Location $Root

$Governor = "0xd0de6a0cff4368a5cb26d1f13595d3c5e0e46972303020d78c11c6ef77e5e10b"

Write-Host "Watching governor $Governor (need >= $MinMist MIST) every ${IntervalSeconds}s..."

while ($true) {
  $balLine = npx tsx -e @"
import { SuiClient, getFullnodeUrl } from '@mysten/sui/client';
const c = new SuiClient({ url: getFullnodeUrl('testnet') });
const b = await c.getBalance({ owner: '$Governor' });
console.log(b.totalBalance);
"@ 2>$null

  if (-not $balLine) {
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] RPC error — retrying..."
    Start-Sleep -Seconds $IntervalSeconds
    continue
  }

  $bal = [bigint]$balLine.Trim()
  $sui = [double]$bal / 1e9
  Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Governor: $bal MIST ($([math]::Round($sui, 4)) SUI)"

  if ($bal -ge $MinMist) {
    Write-Host "Threshold met — running npm run testnet:reality-audit"
    npm run testnet:reality-audit
    exit $LASTEXITCODE
  }

  Start-Sleep -Seconds $IntervalSeconds
}
