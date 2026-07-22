LLVM with DirectX enabled is required to build LDC for `-mdcompute-targets=directx-*`
and to run `tests/dcompute/directx_harness`.

Apply `llvm-directx-dxc-parity.patch` on llvm-project (main or the revision you
build LDC against). It updates `llvm/lib/Target/DirectX` and adds/updates lit
tests under `llvm/test/CodeGen/DirectX`.

Suggested upstream commit title:

  [DirectX] Emit llvm.ident and align DXIL bitcode with DXC

Build:

  cmake -G Ninja -DLLVM_ENABLE_PROJECTS=clang -DLLVM_TARGETS_TO_BUILD=DirectX ...
  ninja
  ninja install   # e.g. CMAKE_INSTALL_PREFIX=C:/llvm-dx

Point LDC at that LLVM (`LLVM_CONFIG`, `LLVM_ROOT`), rebuild `ldc2`, then:

  tests\dcompute\directx_harness\run.ps1 -Hardware

Expected: dxv OK, CreateComputePipelineState OK, output[0]==42 on WARP and NVIDIA.
