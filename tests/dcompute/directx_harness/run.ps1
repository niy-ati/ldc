param(
    [string]$Ldc2 = "C:\ldc-build\bin\ldc2.exe",
    [string]$HarnessExe = "C:\ldc-build\bin\ldc_dx_harness.exe",
    [string]$Config = "Release",
    [switch]$Hardware
)

$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $here

$dxv = "C:\Users\niyat\AppData\Local\Microsoft\WinGet\Packages\Microsoft.DirectX.ShaderCompiler_Microsoft.Winget.Source_8wekyb3d8bbwe\bin\x64\dxv.exe"

function Ensure-HarnessExe {
    param([string]$Exe)
    $main = Join-Path $here "main.cpp"
    $needsBuild = -not (Test-Path $Exe)
    if (-not $needsBuild -and (Test-Path $main)) {
        $needsBuild = (Get-Item $main).LastWriteTimeUtc -gt (Get-Item $Exe).LastWriteTimeUtc
    }
    if ($needsBuild) {
        Write-Host "Building harness host -> $Exe (avoids Device Guard under 'New folder')..."
        & (Join-Path $here "build_harness.ps1") -OutExe $Exe -MainCpp $main
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }
}

Ensure-HarnessExe -Exe $HarnessExe

Write-Host "Compiling harness_kernel.d with LDC..."
& $Ldc2 -c -m64 -mdcompute-targets=directx-660 -mdcompute-file-prefix=harness `
    -output-ll -output-o "$here\harness_kernel.d"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$dxil = Join-Path $here "harness_directx660_64.dxil"
$ll = Join-Path $here "harness_directx660_64.ll"
if (-not (Test-Path $dxil)) { Write-Error "Missing $dxil" }

Write-Host "dxv (validate)..."
& $dxv $dxil
if ($LASTEXITCODE -ne 0) { Write-Error "dxv failed - fix IR before signing" }

$signed = Join-Path $here "harness_signed.dxil"
Write-Host "dxv -o (sign)..."
& $dxv "-o=$signed" $dxil
if ($LASTEXITCODE -ne 0) { Write-Error "dxv sign failed" }

$entryLine = Select-String -Path $ll -Pattern 'define void @(.*_kernel)\(\)' | Select-Object -First 1
if (-not $entryLine) { Write-Error "Could not find *_kernel entry in $ll" }
$entry = $entryLine.Matches[0].Groups[1].Value
Write-Host "Entry: $entry"

$exe = $HarnessExe
if (-not (Test-Path $exe)) { Write-Error "Missing harness: $exe" }
$runArgs = @($signed, $entry, "42.0")
if (-not $Hardware) { $runArgs += "--warp" }
Write-Host ("Running: {0} {1}" -f $exe, ($runArgs -join ' '))
& $exe @runArgs
exit $LASTEXITCODE
