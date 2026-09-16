# MandateOS Phase 7.1 — Deployment Readiness Verification (dry-run)
# Does not publish, spend gas, or modify protocol/SDK/frontend.
param(
    [switch]$SkipDocsDryRun
)

$ErrorActionPreference = "Continue"
$Root = Join-Path $PSScriptRoot "..\.."
$Failures = 0

function Check($ok, $label) {
    if ($ok) { Write-Host "[PASS] $label" -ForegroundColor Green }
    else { Write-Host "[FAIL] $label" -ForegroundColor Red; $script:Failures++ }
}

Write-Host "`n=== MandateOS Deployment Readiness (7.1) ===" -ForegroundColor Cyan
Set-Location $Root

# 1. Sui CLI
$SuiExe = if ($env:SUI_BIN) { $env:SUI_BIN } else { Join-Path $Root "mandateos\.tools\sui\sui.exe" }
Check (Test-Path $SuiExe) "Sui CLI exists at mandateos/.tools/sui/sui.exe"
if (Test-Path $SuiExe) {
    $ver = & $SuiExe --version 2>&1
    Write-Host "       $ver"
    Check ($ver -match "sui") "Sui CLI responds to --version"
}

# 2. Publish dry-run (build + test only)
Write-Host "`n--- testnet:publish (dry-run) ---" -ForegroundColor Yellow
& powershell -ExecutionPolicy Bypass -File "$Root\mandateos\scripts\publish-testnet.ps1" -DryRun
Check ($LASTEXITCODE -eq 0) "publish-testnet.ps1 -DryRun"

# 3. testnet:proof preflight (must fail gracefully without PACKAGE_ID)
Write-Host "`n--- testnet:proof (preflight) ---" -ForegroundColor Yellow
$proofOut = npm run testnet:proof 2>&1 | Out-String
Check ($proofOut -match "MANDATEOS_PACKAGE_ID") "testnet:proof requires MANDATEOS_PACKAGE_ID"

# 4. Schema + explorer validation (fixtures)
Write-Host "`n--- validate-proof-artifacts (fixture) ---" -ForegroundColor Yellow
node scripts/validate-proof-artifacts.mjs --fixture
Check ($LASTEXITCODE -eq 0) "proof artifact schema validation (fixtures)"

# 5. testnet:docs dry-run
if (-not $SkipDocsDryRun) {
    Write-Host "`n--- testnet:docs (dry-run) ---" -ForegroundColor Yellow
    $fixtureDep = Join-Path $Root "proof\fixtures\deployment.sample.json"
    $fixtureRes = Join-Path $Root "proof\fixtures\testnet-results.sample.json"
    $realDep = Join-Path $Root "proof\deployment.json"
    $realRes = Join-Path $Root "proof\testnet-results.json"
    $depBackup = $null; $resBackup = $null
    if (Test-Path $realDep) { $depBackup = Get-Content $realDep -Raw; Remove-Item $realDep }
    if (Test-Path $realRes) { $resBackup = Get-Content $realRes -Raw; Remove-Item $realRes }
    Copy-Item $fixtureDep $realDep
    Copy-Item $fixtureRes $realRes
    $depMdBackup = if (Test-Path (Join-Path $Root "DEPLOYMENT.md")) { Get-Content (Join-Path $Root "DEPLOYMENT.md") -Raw } else { $null }
    $treasuryMdBackup = if (Test-Path (Join-Path $Root "TREASURY_DEMO.md")) { Get-Content (Join-Path $Root "TREASURY_DEMO.md") -Raw } else { $null }
    npm run testnet:docs 2>&1 | Out-Null
    $docsOk = $LASTEXITCODE -eq 0
    Check $docsOk "testnet:docs generates markdown from fixtures"
    Check (Test-Path (Join-Path $Root "DEPLOYMENT.md")) "DEPLOYMENT.md generated"
    Check (Test-Path (Join-Path $Root "TREASURY_DEMO.md")) "TREASURY_DEMO.md generated"
    Remove-Item $realDep -ErrorAction SilentlyContinue
    Remove-Item $realRes -ErrorAction SilentlyContinue
    if ($depBackup) { Set-Content $realDep $depBackup }
    if ($resBackup) { Set-Content $realRes $resBackup }
    if ($depMdBackup) { Set-Content (Join-Path $Root "DEPLOYMENT.md") $depMdBackup }
    if ($treasuryMdBackup) { Set-Content (Join-Path $Root "TREASURY_DEMO.md") $treasuryMdBackup }
}

# 6. npm scripts registered
Write-Host "`n--- npm scripts ---" -ForegroundColor Yellow
$pkg = Get-Content package.json -Raw | ConvertFrom-Json
foreach ($script in @("testnet:publish", "testnet:proof", "testnet:fund", "testnet:docs", "testnet:verify")) {
    Check ($pkg.scripts.PSObject.Properties.Name -contains $script) "package.json has $script"
}

# 7. Docs reference workflow
Write-Host "`n--- documentation ---" -ForegroundColor Yellow
$readme = Get-Content README.md -Raw
$deploy = Get-Content DEPLOYMENT.md -Raw
Check ($readme -match "testnet:publish") "README references testnet:publish"
Check ($readme -match "testnet:proof") "README references testnet:proof"
Check ($deploy -match "testnet:docs") "DEPLOYMENT.md references testnet:docs"
Check (Test-Path DEPLOYMENT_CHECKLIST.md) "DEPLOYMENT_CHECKLIST.md exists"

Write-Host "`n=== Summary: $($Failures) failure(s) ===" -ForegroundColor $(if ($Failures -eq 0) { "Green" } else { "Red" })
exit $Failures
