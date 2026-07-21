# Build ldc_dx_harness.exe outside repo paths (Device Guard often blocks exes under "New folder").
param(
    [string]$OutExe = "C:\ldc-build\bin\ldc_dx_harness.exe",
    [string]$MainCpp = (Join-Path $PSScriptRoot "main.cpp")
)

$ErrorActionPreference = "Stop"
$vcvarsCandidates = @(
    "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat",
    "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat",
    "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\Professional\VC\Auxiliary\Build\vcvars64.bat"
)
$vcvars = $vcvarsCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $vcvars) { throw "vcvars64.bat not found; open a x64 Native Tools prompt and run cl manually." }

$outDir = Split-Path -Parent $OutExe
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$mainObj = Join-Path $outDir "ldc_dx_harness_main.obj"
cmd /c "`"$vcvars`" >nul && cl /nologo /std:c++17 /EHsc /O2 /c /Fo:`"$mainObj`" `"$MainCpp`" && link /nologo /OUT:`"$OutExe`" `"$mainObj`" d3d12.lib dxgi.lib ole32.lib"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Host "Built $OutExe"
