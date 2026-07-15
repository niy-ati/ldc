# DirectX dcompute smoke harness

Minimal C++ D3D12 host for **LDC-generated** DXIL — used to debug the
provisional arg-buffer ABI before committing to it.

## What it does

1. Compile `harness_kernel.d` with `ldc2 -mdcompute-targets=directx-660`
2. Prefer the embedded **RTS0** root signature (SRV t0 / space0)
3. Pack `{ u32 outputGpuVa }` into the arg buffer and dispatch `*_kernel`
4. Readback and check `output[0] == 42` when PSO creation succeeds

## Build / run

```powershell
cmake -B build -G "Visual Studio 17 2022" -A x64
cmake --build build --config Release
.\run.ps1 -Ldc2 C:\ldc-build\bin\ldc2.exe
```

## Current failure mode (reportable)

`CreateComputePipelineState` returns `E_INVALIDARG` for LDC DXIL on this box.

Compared to a working DXC saxpy DXIL:

| | LDC harness DXIL | DXC saxpy (works) |
|--|------------------|-------------------|
| PSV0 | present, entry = `*_kernel`, threads 8,1,1 | present, entry = `main` |
| RTS0 | present (SRV table) | usually none (host builds RS) |
| HASH | **all-zero** | non-zero |
| STAT | **missing** | present |

So the gap is currently **LLVM DXIL container / runtime acceptance**, not the
arg-buffer packing logic (that path never runs until PSO succeeds).

Next iteration: get LDC DXIL past `CreateComputePipelineState` (validator /
hash / container fields), then debug the `f(*args)` unpacking.
