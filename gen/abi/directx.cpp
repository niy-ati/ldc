//===-- gen/abi/directx.cpp -------------------------------------*- C++ -*-===//
//
//                         LDC – the LLVM D compiler
//
// This file is distributed under the BSD-style LDC license. See the LICENSE
// file for details.
//
//===----------------------------------------------------------------------===//

#include "gen/abi/abi.h"
#include "gen/dcompute/druntime.h"
#include "gen/uda.h"
#include "dmd/declaration.h"
#include "gen/tollvm.h"
#include "gen/dcompute/abi-rewrites.h"

using namespace dmd;

/// ABI for DirectX / DXIL dcompute kernels.
/// Calling convention stays C. The synthesised *_kernel wrapper is the
/// compute entry (HLSL attrs); the D @kernel body is a plain callee — same
/// split as SPIRVVulkanTargetABI (core = SPIR_FUNC, wrapper = entry).
struct DirectXTargetABI : TargetABI {
  DComputePointerRewrite pointerRewite;

  llvm::CallingConv::ID callingConv(LINK l) override {
    assert(l == LINK::c);
    return llvm::CallingConv::C;
  }

  llvm::CallingConv::ID callingConv(FuncDeclaration *fdecl) override {
    (void)fdecl;
    return llvm::CallingConv::C;
  }

  bool passByVal(TypeFunction *, Type *t) override {
    return DtoIsInMemoryOnly(t) && isPOD(t) && size(t) > 64;
  }

  bool returnInArg(TypeFunction *tf, bool) override {
    return DtoIsInMemoryOnly(tf->next);
  }

  void rewriteArgument(IrFuncTy &fty, IrFuncTyArg &arg) override {
    TargetABI::rewriteArgument(fty, arg);
    if (arg.rewrite)
      return;

    Type *ty = arg.type->toBasetype();
    std::optional<DcomputePointer> ptr;
    if (ty->ty == TY::Tstruct &&
        (ptr = toDcomputePointer(static_cast<TypeStruct *>(ty)->sym))) {
      pointerRewite.applyTo(arg);
    }
  }
};

TargetABI *createDirectXABI() { return new DirectXTargetABI(); }
