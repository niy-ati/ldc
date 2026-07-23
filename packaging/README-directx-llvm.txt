LLVM with DirectX enabled is required to build LDC for `-mdcompute-targets=directx-*`
and to run `tests/dcompute/directx_harness`.

Apply `llvm-directx-dxc-parity.patch` on llvm-project (revision you build LDC
against). Current patch focus:

  - DXIL bitcode writer alignment with DXC (datalayout, KIND table, metadata
    block layout/order, opaque pointer handling). Under HLSL review; bisect
    what remains load-bearing after frontend !llvm.ident.
  - !llvm.ident is NOT invented in the DirectX backend. LDC emits it on the
    dcompute device Module in gen/dcompute/targetDirectX.cpp (same idea as
    host CodeGenerator). Clang/DXC already emit it.

Suggested commit titles (split when upstreaming):

  [DirectX] Align DXIL bitcode writer with DXC
  (LDC separately: emit !llvm.ident on DirectX dcompute modules)

Build:

  cmake -G Ninja -DLLVM_ENABLE_PROJECTS=clang -DLLVM_TARGETS_TO_BUILD=DirectX ...
  ninja
  ninja install

Point LDC at that LLVM, rebuild ldc2, then:

  tests\dcompute\directx_harness\run.ps1 -Hardware

Expected: dxv OK, CreateComputePipelineState OK, output[0]==42 on WARP and NVIDIA.
