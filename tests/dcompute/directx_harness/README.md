# DirectX dcompute smoke harness

Minimal C++ D3D12 host for **LDC-generated** DXIL.

## Current ABI (`targetDirectX.cpp`)

`*_kernel` writes through **UAV RawBuffer u0** (`handlefrombinding` + `getpointer`).
Cores are AlwaysInline + mem2reg so stores lower to `rawBufferStore`.
Module emits `!dx.valver = {1,8}` so Microsoft `dxv` accepts PSV v3.

## Required host pipeline

1. Compile: `ldc2 -mdcompute-targets=directx-660`
2. `dxv kernel.dxil` must succeed
3. **Sign:** `dxv -o=signed.dxil kernel.dxil` (LLVM leaves container header hash zero)
4. Hand-built **UAV(u0)** root-sig (LLVM `RTS0` is rejected by `CreateRootSignature`)
5. Run with `--warp` or hardware (after LLVM DXIL writer fix below)

## NVIDIA CreateCPS fix (LLVM)

Hardware `CreateComputePipelineState` AVs on dxv-clean LLVM DXIL that omits
`!llvm.ident` (WARP accepts it). DXC always emits that named MD.

Also needed in the DXIL bitcode writer: DXC-matching datalayout / KIND table,
`METADATA_BLOCK` codeLen 3, MD-before-KINDs order, and opaque-pointer → typed
`i8*` redirection so the type table does not forward-ref non-struct types.

Rebuild LDC against an LLVM that includes those `Target/DirectX` changes, then
hardware CreateCPS should succeed the same as WARP.

## Build / run

```powershell
.\run.ps1 -Ldc2 C:\ldc-build\bin\ldc2.exe           # WARP (default) — E2E verify 42
.\run.ps1 -Ldc2 C:\ldc-build\bin\ldc2.exe -Hardware # NVIDIA (needs rebuilt LLVM/LDC)
```

The D3D12 host is built to **`C:\ldc-build\bin\ldc_dx_harness.exe`** (same tree as
`ldc2`). Some org **Device Guard** policies block new `.exe` files under paths like
`New folder`; if `run.ps1` still fails, build once from an elevated or IT-approved
shell: `.\build_harness.ps1`, or pass `-HarnessExe` to an allowlisted path.

## Status

| Step | Result |
|------|--------|
| dxv on fresh LDC DXIL | pass |
| dxv -o sign | pass |
| CreateCPS + dispatch on WARP | pass (`output[0]==42`) |
| CreateCPS on NVIDIA HW | pass after LLVM `llvm.ident` + bitcode writer fixes |
| LLVM RTS0 | CreateRootSignature fails — ignore |
