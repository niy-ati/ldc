// DirectX dcompute: wrapper entry + HLSL attrs + dx.resource arg packing.
// Mirrors Vulkan PR vulkan_minimal_kernel.d (wrapper calls core).
//
// REQUIRES: target_DirectX
// RUN: %ldc -c -m64 -mdcompute-targets=directx-660 -mdcompute-file-prefix=dx_wrap -output-ll -output-o %s
// RUN: FileCheck %s --check-prefix=LL < dx_wrap_directx660_64.ll

@compute(CompileFor.deviceOnly) module dcompute_dx_kernel_wrapper;
import ldc.dcompute;

// LL: target triple = "dxil-pc-shadermodel6.6-compute"

// Wrapper entry (zero args) carries HLSL attrs — like Vulkan *_kernel.
// LL: define void @{{.*}}_kernel()
// LL: call {{.*}} @llvm.dx.resource.handlefrombinding
// LL: call {{.*}} @llvm.dx.resource.getpointer
// LL: call void @{{.*}}minimal_kernel{{.*}}(
// LL: ret void

// Core D body keeps the real parameter list.
// LL: define{{.*}} @{{.*}}minimal_kernel{{.*}}(
// LL-SAME: ptr addrspace(1)

// LL: attributes #{{[0-9]+}} = { {{.*}}"exp-shader"="cs"{{.*}}"hlsl.numthreads"="8,1,1"{{.*}}"hlsl.shader"="compute"{{.*}} }

@kernel([8, 1, 1]) void minimal_kernel(GlobalPointer!float output) {
    *output = 42.0f;
}
