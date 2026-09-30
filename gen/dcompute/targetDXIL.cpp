//===-- gen/dcompute/targetDXIL.cpp ---------------------------------------===//
//
//                         LDC – the LLVM D compiler
//
// This file is distributed under the BSD-style LDC license. See the LICENSE
// file for details.
//
//===----------------------------------------------------------------------===//

#include "gen/dcompute/target.h"
#include "gen/dcompute/druntime.h"
#include "gen/passes/metadata.h"
#include "gen/abi/targets.h"
#include "gen/logger.h"
#include "gen/optimizer.h"
#include "gen/to_string.h"
#include "llvm/Target/TargetMachine.h"
#include "llvm/Transforms/Scalar.h"
#include "driver/targetmachine.h"
#include <cstring>

namespace {
class TargetDXIL : public DComputeTarget {
public:
  TargetDXIL(llvm::LLVMContext &c, int sm)
      : DComputeTarget(
            c, sm, ID::DirectX, "directx", "dxil", createWin64ABI(),
            // Map from nominal DCompute address space to DXIL address space.
            // DXIL generally uses flat address spaces, so we default everything to 0
            // (Private = 0, Global = 0, Shared = 3 (groupshared typically uses AS 3 in DXIL), Constant = 0, Generic = 0)
            {{0, 0, 3, 0, 0}}) {

    auto tripleString = "dxil-pc-shadermodel6.6-compute";
    auto floatABI = ::FloatABI::Hard;
    
    // We attempt to create the target machine for DXIL
    targetMachine = createTargetMachine(
        tripleString, "dxil",
        "", {},
        ExplicitBitness::M32, floatABI,
        llvm::Reloc::Static, llvm::CodeModel::Medium, codeGenOptLevel(), false);

    _ir = new IRState("dcomputeTargetDXIL", ctx);
#if LLVM_VERSION_MAJOR >= 21
    _ir->module.setTargetTriple(llvm::Triple(tripleString));
#else
    _ir->module.setTargetTriple(tripleString);
#endif
    if (targetMachine) {
        _ir->module.setDataLayout(targetMachine->createDataLayout());
    }
    _ir->dcomputetarget = this;
  }

  void addMetadata() override {
    // We need to add the validator version for DXIL to pass verification
    llvm::Metadata *valVer[] = {
        llvm::ConstantAsMetadata::get(llvm::ConstantInt::get(llvm::IntegerType::get(ctx, 32), 1)),
        llvm::ConstantAsMetadata::get(llvm::ConstantInt::get(llvm::IntegerType::get(ctx, 32), 6))
    };
    llvm::MDNode *valNode = llvm::MDTuple::get(ctx, valVer);
    llvm::NamedMDNode *valMD = _ir->module.getOrInsertNamedMetadata("dx.valver");
    valMD->addOperand(valNode);
  }

  void addKernelMetadata(FuncDeclaration *df, llvm::Function *llf, StructLiteralExp *_unused_) override {
    // Generate dx.entryPoints metadata
    llvm::NamedMDNode *entryPoints =
        _ir->module.getOrInsertNamedMetadata("dx.entryPoints");
    
    // An entry point is a tuple of:
    // [ Function, Name, Signatures (null for compute), Resources (null for bindless), Tag Tuple ]
    llvm::Metadata *fn = llvm::ConstantAsMetadata::get(llf);
    llvm::Metadata *name = llvm::MDString::get(ctx, llf->getName());
    
    // Compute Shader Tag: [ 5, [ numthreads_x, numthreads_y, numthreads_z ] ]
    llvm::Metadata *tagKind = llvm::ConstantAsMetadata::get(
        llvm::ConstantInt::get(llvm::IntegerType::get(ctx, 32), 5)); // 5 == Shader Flags / NumThreads
    
    // Extract thread group sizes (placeholder: 1, 1, 1 for now if we can't parse it)
    llvm::Metadata *dims[] = {
        llvm::ConstantAsMetadata::get(llvm::ConstantInt::get(llvm::IntegerType::get(ctx, 32), 1)),
        llvm::ConstantAsMetadata::get(llvm::ConstantInt::get(llvm::IntegerType::get(ctx, 32), 1)),
        llvm::ConstantAsMetadata::get(llvm::ConstantInt::get(llvm::IntegerType::get(ctx, 32), 1))
    };
    llvm::MDNode *dimNode = llvm::MDTuple::get(ctx, dims);
    
    llvm::Metadata *tagProps[] = { tagKind, dimNode };
    llvm::MDNode *tagNode = llvm::MDTuple::get(ctx, tagProps);
    
    llvm::Metadata *tagTuple[] = { tagNode };
    llvm::MDNode *tags = llvm::MDTuple::get(ctx, tagTuple);
    
    llvm::Metadata *arr[] = {fn, name, nullptr, nullptr, tags};
    llvm::MDNode *tup = llvm::MDTuple::get(ctx, arr);
    
    entryPoints->addOperand(tup);
  }
};
} // anonymous namespace.

DComputeTarget *createDXILTarget(llvm::LLVMContext &c, int sm) {
  return new TargetDXIL(c, sm);
};
