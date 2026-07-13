// DirectX dcompute: kernel metadata + DXIL compute triple.
// Pattern mirrors tests/codegen/dcompute_*.d and Vulkan PR vulkan_minimal_kernel.d
// (attrs only for now — no kernel wrapper / resource ABI yet).
//
// REQUIRES: target_DirectX
// RUN: %ldc -c -m64 -mdcompute-targets=directx-660 -mdcompute-file-prefix=dx_attrs -output-ll -output-o %s
// RUN: FileCheck %s --check-prefix=LL < dx_attrs_directx660_64.ll

@compute(CompileFor.deviceOnly) module dcompute_dx_kernel_attrs;
import ldc.dcompute;

// LL: target triple = "dxil-pc-shadermodel6.6-compute"

// LL: define{{.*}} @{{.*}}minimal_kernel{{.*}}(
// LL-SAME: ptr addrspace(1)

// LL: attributes #{{[0-9]+}} = {
// LL-DAG: "hlsl.shader"="compute"
// LL-DAG: "hlsl.numthreads"="8,1,1"
// LL-DAG: "exp-shader"="cs"

@kernel([8, 1, 1]) void minimal_kernel(GlobalPointer!float output) {
    *output = 42.0f;
}
