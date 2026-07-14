# DirectX dcompute smoke harness

Minimal C++ D3D12 host to exercise LDC-generated DXIL kernels and debug the
provisional arg-buffer ABI (`dx.RawBuffer` + `llvm.dx.resource.*` in
`targetDirectX.cpp`).

## What it does

1. Compiles `harness_kernel.d` with `ldc2 -mdcompute-targets=directx-660`
2. Loads the `.dxil` blob and creates a root signature (SRV `t0`, space `0`)
3. Uploads an arg buffer `{ u32 outputGpuVa }` and dispatches `*_kernel`
4. Readbacks the output buffer and checks `output[0] == 42`

## Build (Windows + VS Build Tools)

```powershell
cd tests/dcompute/directx_harness
cmake -B build -G "Visual Studio 17 2022" -A x64
cmake --build build --config Release
```

## Run

```powershell
.\run.ps1 -Ldc2 C:\ldc-build\bin\ldc2.exe
```

Pass `--debug` as the last argument to enable the D3D12 debug layer and print
validation messages on PSO failure.

## Current status (expected while ABI matures)

- LDC now emits `!dx.rootsignatures` + an **RTS0** part for the arg-buffer SRV.
- `CreateComputePipelineState` may still fail with `E_INVALIDARG` on some
  Windows + LLVM-DXIL combinations — treat that as a signal to iterate (root
  signature layout, entry symbol, or DXIL/runtime version), not a harness bug.
- When PSO creation succeeds but verification fails, the arg-buffer / GPU VA
  packing is the next thing to fix.

Report harness output when iterating on the ABI with Nicholas.
