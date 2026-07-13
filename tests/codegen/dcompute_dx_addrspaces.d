// DirectX dcompute address-space mapping (Shared → AS 3, matching Clang groupshared).
// See gen/dcompute/targetDirectX.cpp mapping {{0, 1, 3, 2, 0}}.
//
// REQUIRES: target_DirectX
// RUN: %ldc -c -m64 -mdcompute-targets=directx-660 -mdcompute-file-prefix=dx_as -output-ll -output-o %s
// RUN: FileCheck %s --check-prefix=LL < dx_as_directx660_64.ll

@compute(CompileFor.deviceOnly) module dcompute_dx_addrspaces;
import ldc.dcompute;

// LL: %"ldc.dcompute.Pointer!(AddrSpace.Private, float).Pointer" = type { ptr }
// LL: %"ldc.dcompute.Pointer!(AddrSpace.Global, float).Pointer" = type { ptr addrspace(1) }
// LL: %"ldc.dcompute.Pointer!(AddrSpace.Shared, float).Pointer" = type { ptr addrspace(3) }
// LL: %"ldc.dcompute.Pointer!(AddrSpace.Constant, immutable(float)).Pointer" = type { ptr addrspace(2) }
// LL: %"ldc.dcompute.Pointer!(AddrSpace.Generic, float).Pointer" = type { ptr }

void foo(PrivatePointer!float f) {
    // LL: load float, ptr
    float g = *f;
}

void foo(GlobalPointer!float f) {
    // LL: load float, ptr addrspace(1)
    float g = *f;
}

void foo(SharedPointer!float f) {
    // LL: load float, ptr addrspace(3)
    float g = *f;
}

void foo(ConstantPointer!float f) {
    // LL: load float, ptr addrspace(2)
    float g = *f;
}

void foo(GenericPointer!float f) {
    // LL: load float, ptr
    float g = *f;
}
