param(
    [string]$Ldc2 = "C:\ldc-build\bin\ldc2.exe",
    [string]$Config = "Release"
)

$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $here

if (-not (Test-Path "build\${Config}\ldc_dx_harness.exe")) {
    Write-Host "Building harness..."
    cmake -B build -G "Visual Studio 17 2022" -A x64 | Out-Host
    cmake --build build --config $Config | Out-Host
}

Write-Host "Compiling harness_kernel.d with LDC..."
& $Ldc2 -c -m64 -mdcompute-targets=directx-660 -mdcompute-file-prefix=harness `
    -output-o "$here\harness_kernel.d"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$dxil = Join-Path $here "harness_directx660_64.dxil"
if (-not (Test-Path $dxil)) {
    Write-Error "Missing $dxil"
}

# Also emit IR so we can scrape the wrapper entry.
& $Ldc2 -c -m64 -mdcompute-targets=directx-660 -mdcompute-file-prefix=harness `
    -output-ll -output-o "$here\harness_kernel.d" | Out-Null
$ll = Join-Path $here "harness_directx660_64.ll"
$entryLine = Select-String -Path $ll -Pattern 'define void @(.*_kernel)\(\)' | Select-Object -First 1
if (-not $entryLine) { Write-Error "Could not find *_kernel entry in $ll" }
$entry = $entryLine.Matches[0].Groups[1].Value
Write-Host "Entry: $entry"

$exe = Join-Path $here "build\${Config}\ldc_dx_harness.exe"
& $exe $dxil $entry 42.0 --debug
exit $LASTEXITCODE
