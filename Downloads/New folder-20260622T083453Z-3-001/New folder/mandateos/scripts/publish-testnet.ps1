# MandateOS - Publish to Sui Testnet (Phase 7 / 7.1)
param(
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

$SuiExe = if ($env:SUI_BIN) { $env:SUI_BIN } else { Join-Path $PSScriptRoot "..\.tools\sui\sui.exe" }
$RepoRoot = Join-Path $PSScriptRoot ".."
$ProofDir = Join-Path $RepoRoot "..\proof"
$Governor = "0xd0de6a0cff4368a5cb26d1f13595d3c5e0e46972303020d78c11c6ef77e5e10b"
$RequiredProtocol = 126

function Write-Check($ok, $msg) {
    if ($ok) { Write-Host "[PASS] $msg" -ForegroundColor Green }
    else { Write-Host "[FAIL] $msg" -ForegroundColor Red }
}

function Invoke-Sui {
    param([string[]]$SuiArgs)
    $prev = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $out = & $SuiExe @SuiArgs 2>&1
    $code = $LASTEXITCODE
    $ErrorActionPreference = $prev
    return @{ Out = $out; Code = $code; Text = ($out | Out-String) }
}

$dryLabel = ""
if ($DryRun) { $dryLabel = " (DRY RUN)" }

Write-Host "MandateOS - Testnet Publish$dryLabel" -ForegroundColor Cyan
Write-Host "Sui CLI: $SuiExe"

if (-not (Test-Path $SuiExe)) {
    Write-Check $false "Sui CLI not found at $SuiExe"
    exit 1
}

$cliVersion = (& $SuiExe --version 2>&1) -replace '^sui\s+', ''
Write-Host "CLI version: $cliVersion"

& $SuiExe client switch --env testnet | Out-Null
& $SuiExe client switch --address kind-chrysolite | Out-Null

Push-Location $RepoRoot
try {
    $publishProbe = (Invoke-Sui -SuiArgs @("client", "publish", "--gas-budget", "2000000000", "--dry-run")).Text
    $protoPattern = 'protocol version is (\d+).*network.s protocol version is (\d+)'
    if ($publishProbe -match $protoPattern) {
        $cliProto = [int]$Matches[1]
        $netProto = [int]$Matches[2]
        Write-Host "CLI protocol: $cliProto | Testnet protocol: $netProto" -ForegroundColor Yellow
        if ($cliProto -lt $netProto) {
            Write-Check $false "CLI protocol $cliProto below testnet $netProto - upgrade required before publish"
            Write-Host "Upgrade: see DEPLOYMENT_CHECKLIST.md" -ForegroundColor Yellow
            if (-not $DryRun) { exit 3 }
        } else {
            Write-Check $true "CLI protocol compatible with testnet"
        }
    } else {
        Write-Check $true "No protocol version mismatch detected"
    }

    Write-Host ""
    Write-Host "Building..." -ForegroundColor Yellow
    $build = Invoke-Sui -SuiArgs @("move", "build")
    if ($build.Code -ne 0) { Write-Check $false "move build"; exit $build.Code }
    Write-Check $true "move build"

    Write-Host ""
    Write-Host "Testing..." -ForegroundColor Yellow
    $test = Invoke-Sui -SuiArgs @("move", "test")
    if ($test.Code -ne 0) { Write-Check $false "move test"; exit $test.Code }
    if ($test.Text -notmatch "passed: 38") {
        Write-Check $false "expected 38/38 tests"
        exit 1
    }
    Write-Check $true "move test (38/38)"

    if ($DryRun) {
        Write-Host ""
        Write-Host "Dry run complete - publish skipped (no gas spent)." -ForegroundColor Cyan
        exit 0
    }

    $gas = & $SuiExe client gas --json | ConvertFrom-Json
    if (-not $gas -or $gas.Count -eq 0) {
        Write-Check $false "No testnet gas on $Governor"
        Write-Host "Fund: https://faucet.sui.io/?address=$Governor" -ForegroundColor Yellow
        Write-Host "Or:   npm run testnet:fund" -ForegroundColor Yellow
        exit 2
    }
    $coinCount = $gas.Count
    Write-Check $true "gas available - $coinCount coins"

    New-Item -ItemType Directory -Force -Path $ProofDir | Out-Null
    $publishJson = Join-Path $ProofDir "publish-result.json"

    Write-Host ""
    Write-Host "Publishing to testnet..." -ForegroundColor Yellow
    $publish = Invoke-Sui -SuiArgs @("client", "publish", "--gas-budget", "2000000000", "--json")
    $publishOut = $publish.Out
    $publishOut | Out-File -FilePath $publishJson -Encoding utf8

    if ($publish.Code -ne 0) {
        Write-Check $false "client publish"
        Get-Content $publishJson -ErrorAction SilentlyContinue
        exit $publish.Code
    }

    $jsonLine = ($publishOut | Where-Object { $_.ToString().TrimStart().StartsWith("{") }) -join "`n"
    if (-not $jsonLine) { $jsonLine = Get-Content $publishJson -Raw }
    $result = $jsonLine | ConvertFrom-Json

    $published = $result.objectChanges | Where-Object { $_.type -eq "published" }
    $packageId = $published.packageId
    $digest = $result.digest

    if (-not $packageId -or -not $digest) {
        Write-Check $false "could not parse packageId/digest from publish output"
        exit 1
    }

    Write-Host ""
    Write-Host "Package ID: $packageId" -ForegroundColor Green
    Write-Host "Digest:     $digest" -ForegroundColor Green
    Write-Host "Explorer:   https://suiscan.xyz/testnet/tx/$digest"

    $deployment = @{
        packageId = $packageId
        digest = $digest
        governor = $Governor
        network = "testnet"
        publishedAt = (Get-Date).ToString("o")
        cliVersion = $cliVersion
        protocolVersion = $RequiredProtocol
    }
    $deployment | ConvertTo-Json | Set-Content (Join-Path $ProofDir "deployment.json")

    Write-Check $true "proof/deployment.json written"
}
finally {
    Pop-Location
}
