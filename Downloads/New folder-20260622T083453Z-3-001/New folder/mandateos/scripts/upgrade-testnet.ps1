# MandateOS - Upgrade deployed package on Sui testnet (fixes treasury vec_map::insert)
param(
    [string]$GasBudget = "150000000"
)

$ErrorActionPreference = "Stop"

$SuiExe = if ($env:SUI_BIN) { $env:SUI_BIN } else { Join-Path $PSScriptRoot ".tools\sui\sui.exe" }
$RepoRoot = Join-Path $PSScriptRoot ".."
$ProofDir = Join-Path $RepoRoot "..\proof"
$UpgradeCap = "0x8133621db94776a6f146163d249695f5e6b30fdf7bcd972afd21fce3846d284f"
$PackageId = "0x7d6ce0ae17d3b23cd36a2e7828afe3c90294e92f66565ac644871acb9080217b"
$Governor = "0xd0de6a0cff4368a5cb26d1f13595d3c5e0e46972303020d78c11c6ef77e5e10b"

function Write-Check($ok, $msg) {
    if ($ok) { Write-Host "[PASS] $msg" -ForegroundColor Green }
    else { Write-Host "[FAIL] $msg" -ForegroundColor Red }
}

Write-Host "MandateOS - Testnet Upgrade" -ForegroundColor Cyan
Write-Host "Sui CLI: $SuiExe"

if (-not (Test-Path $SuiExe)) {
    Write-Check $false "Sui CLI not found at $SuiExe"
    exit 1
}

& $SuiExe client switch --env testnet | Out-Null
& $SuiExe client switch --address kind-chrysolite | Out-Null

Push-Location $RepoRoot
try {
    Write-Host "Building..." -ForegroundColor Yellow
    & $SuiExe move build
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    Write-Check $true "move build"

    $gas = & $SuiExe client gas --json | ConvertFrom-Json
    $totalMist = ($gas | ForEach-Object { [int64]$_.mistBalance } | Measure-Object -Sum).Sum
    $maxCoin = ($gas | Sort-Object { [int64]$_.mistBalance } -Descending | Select-Object -First 1)
    $maxMist = [int64]$maxCoin.mistBalance
    Write-Host "Gas balance: $totalMist MIST across $($gas.Count) coin(s); largest coin $maxMist MIST (need >= $GasBudget)" -ForegroundColor Yellow
    if ($totalMist -lt [int64]146000000) {
        Write-Check $false "Insufficient gas on $Governor"
        Write-Host "Fund: https://faucet.sui.io/?address=$Governor" -ForegroundColor Yellow
        Write-Host "Or:   npm run testnet:fund" -ForegroundColor Yellow
        exit 2
    }
    if ($maxMist -lt [int64]$GasBudget -and $gas.Count -gt 1) {
        Write-Host "Merging gas coins into primary $($maxCoin.gasCoinId)..." -ForegroundColor Yellow
        $primary = $maxCoin.gasCoinId
        $prevEap = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        foreach ($c in $gas) {
            if ($c.gasCoinId -eq $primary) { continue }
            & $SuiExe client merge-coin --primary-coin $primary --coin-to-merge $c.gasCoinId --gas-budget 10000000 2>&1 | Out-Null
        }
        $ErrorActionPreference = $prevEap
        $gas = & $SuiExe client gas --json | ConvertFrom-Json
        $maxCoin = ($gas | Sort-Object { [int64]$_.mistBalance } -Descending | Select-Object -First 1)
        $maxMist = [int64]$maxCoin.mistBalance
        Write-Host "After merge: largest coin $maxMist MIST" -ForegroundColor Yellow
    }
    if ($maxMist -lt [int64]$GasBudget) {
        Write-Check $false "No single gas coin >= $GasBudget MIST (largest $maxMist). Send one larger coin to governor."
        exit 2
    }

    Write-Host "Dry run..." -ForegroundColor Yellow
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $dry = & $SuiExe client upgrade --upgrade-capability $UpgradeCap --gas-budget $GasBudget --dry-run 2>&1 | Out-String
    $dryExit = $LASTEXITCODE
    $ErrorActionPreference = $prevEap
    if ($dryExit -ne 0 -and $dry -notmatch "Dry run completed, execution status: success") {
        Write-Check $false "upgrade dry-run (exit $dryExit)"
        Write-Host $dry
        exit 3
    }
    if ($dry -notmatch "Dry run completed, execution status: success") {
        Write-Check $false "upgrade dry-run"
        Write-Host $dry
        exit 3
    }
    Write-Check $true "upgrade dry-run"

    Write-Host "Upgrading on testnet..." -ForegroundColor Yellow
    $ErrorActionPreference = 'Continue'
    $out = & $SuiExe client upgrade --upgrade-capability $UpgradeCap --gas-budget $GasBudget --json 2>&1
    $upgradeExit = $LASTEXITCODE
    $ErrorActionPreference = $prevEap
    $outText = ($out | Out-String)
    $jsonLine = $null
    if ($outText -match '\{\s*"digest"\s*:\s*"[^"]+"') {
        $start = $outText.IndexOf('{')
        $depth = 0
        for ($i = $start; $i -lt $outText.Length; $i++) {
            if ($outText[$i] -eq '{') { $depth++ }
            elseif ($outText[$i] -eq '}') {
                $depth--
                if ($depth -eq 0) {
                    $jsonLine = $outText.Substring($start, $i - $start + 1)
                    break
                }
            }
        }
    }
    if (-not $jsonLine) {
        Write-Check $false "upgrade returned no JSON (exit $upgradeExit)"
        $out | ForEach-Object { Write-Host $_ }
        exit 4
    }

    $result = $jsonLine | ConvertFrom-Json
    $digest = $result.digest
    if (-not $digest) {
        Write-Check $false "could not parse upgrade digest"
        exit 5
    }

    $upgraded = $result.objectChanges | Where-Object { $_.type -eq "published" }
    $newVersion = $upgraded.version
    Write-Host ""
    Write-Host "Package ID: $PackageId (unchanged)" -ForegroundColor Green
    Write-Host "Version:    $newVersion" -ForegroundColor Green
    Write-Host "Digest:     $digest" -ForegroundColor Green
    Write-Host "Explorer:   https://suiscan.xyz/testnet/tx/$digest"

    New-Item -ItemType Directory -Force -Path $ProofDir | Out-Null
    $deploymentPath = Join-Path $ProofDir "deployment.json"
    $deployment = @{
        network = "testnet"
        packageId = $PackageId
        digest = $digest
        upgradeDigest = $digest
        upgradeCapId = $UpgradeCap
        governor = $Governor
        upgradedAt = (Get-Date).ToString("o")
        packageVersion = $newVersion
        explorer = @{
            package = "https://suiscan.xyz/testnet/object/$PackageId"
            upgradeTx = "https://suiscan.xyz/testnet/tx/$digest"
        }
    }
    if (Test-Path $deploymentPath) {
        $existing = Get-Content $deploymentPath -Raw | ConvertFrom-Json
        foreach ($prop in $existing.PSObject.Properties) {
            if (-not $deployment.Contains($prop.Name)) {
                $deployment[$prop.Name] = $prop.Value
            }
        }
        $deployment.upgradeDigest = $digest
        $deployment.upgradedAt = (Get-Date).ToString("o")
    }
    $deployment | ConvertTo-Json -Depth 6 | Set-Content $deploymentPath
    $jsonLine | Out-File (Join-Path $ProofDir "upgrade-result.json") -Encoding utf8
    Write-Check $true "proof/deployment.json updated"
}
finally {
    Pop-Location
}
