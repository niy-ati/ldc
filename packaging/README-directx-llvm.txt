LLVM DirectX notes for LDC `-mdcompute-targets=directx-*`.

`llvm-directx-dxc-parity.patch` (against llvm-project near main):

  - dxil-translate-metadata does NOT invent !llvm.ident.
  - Lit checks that frontend-provided !llvm.ident is preserved.
  - No DXIL bitcode-writer DXC-parity changes (bisect showed they are not
    required for NVIDIA CreateCPS once !llvm.ident is present).

LDC emits !llvm.ident on the dcompute device Module in
gen/dcompute/targetDirectX.cpp (host CodeGenerator already did for host IR).

Bisect evidence (RTX 3050): see dcompute-spike/pkgdiff/bisect/RESULTS.md
  - stock writer + ident → CreateCPS OK
  - stock writer + no ident → HW AV; WARP OK

Build LLVM with DirectX enabled, point LDC at it, rebuild ldc2, then:

  tests\dcompute\directx_harness\run.ps1 -Hardware
