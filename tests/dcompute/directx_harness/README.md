# DirectX dcompute smoke harness

Minimal C++ D3D12 host for **LDC-generated** DXIL.

## Current ABI (`targetDirectX.cpp`)

`*_kernel` writes through **UAV RawBuffer u0** (`handlefrombinding` + `getpointer`).
Cores are AlwaysInline + mem2reg so stores lower to `rawBufferStore`.
Module emits `!dx.valver = {1,8}` so Microsoft `dxv` accepts PSV v3.
Device module also emits `!llvm.ident` (same idea as host LDC / DXC).

## Required host pipeline

1. Compile: `ldc2 -mdcompute-targets=directx-660`
2. `dxv kernel.dxil` must succeed
3. **Sign:** `dxv -o=signed.dxil kernel.dxil` (LLVM leaves container header hash zero)
4. Hand-built **UAV(u0)** root-sig (LLVM `RTS0` is rejected by `CreateRootSignature`)
5. Run with `--warp` or hardware (needs LLVM DXIL bitcode writer patches below for NVIDIA)

## NVIDIA CreateCPS / LLVM

Hardware `CreateComputePipelineState` can AV on dxv-clean LLVM DXIL when
`!llvm.ident` is missing (WARP may still accept). Emit ident from the
**frontend** (LDC `targetDirectX`). Bisect (2026-07-23): with frontend ident,
**stock** LLVM DXIL bitcode writer is enough for empty + minimal UAV CreateCPS
on RTX 3050; DXC bitcode-writer parity deltas are not required for that gate.

See `packaging/README-directx-llvm.txt`.

## Build / run

```powershell
.\run.ps1 -Ldc2 C:\ldc-build\bin\ldc2.exe           # WARP (default) — E2E verify 42
.\run.ps1 -Ldc2 C:\ldc-build\bin\ldc2.exe -Hardware # NVIDIA (needs rebuilt LLVM/LDC)
```

The D3D12 host is built to **`C:\ldc-build\bin\ldc_dx_harness.exe`** (same tree as
`ldc2`). Some org **Device Guard** policies block new `.exe` files under paths like
`New folder`; if `run.ps1` still fails, build once from an elevated or IT-approved
shell: `.\build_harness.ps1`, or pass `-HarnessExe` to an allowlisted path.

## Status (verified 2026-07-22, RTX 3050 + WARP)

| Step | Result |
|------|--------|
| dxv on fresh LDC DXIL | pass |
| dxv -o sign | pass |
| CreateCPS + dispatch on WARP | pass (`output[0]==42`) |
| CreateCPS on NVIDIA HW | pass with patched LLVM (`packaging/llvm-directx-dxc-parity.patch`) |
| LLVM RTS0 | CreateRootSignature fails — use hand-built UAV RS in harness |

LLVM patch and rebuild notes: `packaging/README-directx-llvm.txt`.
