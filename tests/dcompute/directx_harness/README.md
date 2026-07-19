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
5. Prefer **`--warp`** — on this NVIDIA box, hardware `CreateCPS` crashes on signed LLVM DXIL even when WARP succeeds

## Build / run

```powershell
.\run.ps1 -Ldc2 C:\ldc-build\bin\ldc2.exe           # WARP (default) — E2E verify 42
.\run.ps1 -Ldc2 C:\ldc-build\bin\ldc2.exe -Hardware # NVIDIA (may crash CreateCPS)
```

## Status

| Step | Result |
|------|--------|
| dxv on fresh LDC DXIL | pass |
| dxv -o sign | pass |
| CreateCPS + dispatch on WARP | pass (`output[0]==42`) |
| CreateCPS on NVIDIA HW | crash inside CreateCPS (open) |
| LLVM RTS0 | CreateRootSignature fails — ignore |
