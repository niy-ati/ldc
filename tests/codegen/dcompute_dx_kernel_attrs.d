// DirectX dcompute: kernel metadata on the wrapper entry (*_kernel).
//
// REQUIRES: target_DirectX
// RUN: %ldc -c -m64 -mdcompute-targets=directx-660 -mdcompute-file-prefix=dx_attrs -output-ll -output-o %s
// RUN: FileCheck %s --check-prefix=LL < dx_attrs_directx660_64.ll

@compute(CompileFor.deviceOnly) module dcompute_dx_kernel_attrs;
import ldc.dcompute;

// LL: target triple = "dxil-pc-shadermodel6.6-compute"
// LL: !llvm.ident = !{!{{[0-9]+}}}

// LL: define void @{{.*}}_kernel()
// LL: attributes #{{[0-9]+}} = { {{.*}}"exp-shader"="cs"{{.*}}"hlsl.numthreads"="8,1,1"{{.*}}"hlsl.shader"="compute"{{.*}} }

@kernel([8, 1, 1]) void minimal_kernel(GlobalPointer!float output) {
    *output = 42.0f;
}
