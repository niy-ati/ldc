// Kernel used by the DirectX dcompute smoke harness (tests/dcompute/directx_harness).
//
// Compile with LDC:
//   ldc2 -c -m64 -mdcompute-targets=directx-660 -mdcompute-file-prefix=harness \
//        -output-o harness_kernel.d
//
// The harness loads harness_directx660_64.dxil and dispatches the *_kernel entry.

@compute(CompileFor.deviceOnly) module harness_kernel;
import ldc.dcompute;

@kernel([8, 1, 1]) void minimal_kernel(GlobalPointer!float output) {
    *output = 42.0f;
}
