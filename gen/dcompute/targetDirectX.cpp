//===-- gen/dcompute/targetDirectX.cpp ------------------------------------===//
//
//                         LDC – the LLVM D compiler
//
// This file is distributed under the BSD-style LDC license. See the LICENSE
// file for details.
//
//===----------------------------------------------------------------------===//
//
// DirectX / DXIL dcompute backend.
//
// Metadata: HLSL function attrs + dxil-pc-shadermodel*-compute triple
// (Clang CodeGenHLSL / llvm/test/CodeGen/DirectX).
//
// Kernel ABI (aligned with Vulkan dcompute): the D @kernel is lowered as a
// "core" function; a zero-arg wrapper entry (*_kernel) carries hlsl.* attrs
// and loads packed arguments via llvm.dx.resource.handlefrombinding /
// getpointer from a dx.RawBuffer — same shape as Vulkan's
// spirv.VulkanBuffer + llvm.spv.resource.* path. Binding layout / final ABI
// details may still track the ongoing Vulkan ABI design.
//
//===----------------------------------------------------------------------===//

#if LDC_LLVM_SUPPORTED_TARGET_DirectX

#include "dmd/expression.h"
#include "dmd/mangle.h"
#include "gen/abi/targets.h"
#include "gen/dcompute/druntime.h"
#include "gen/dcompute/target.h"
#include "gen/logger.h"
#include "gen/optimizer.h"
#include "gen/to_string.h"
#include "gen/tollvm.h"
#include "driver/targetmachine.h"
#include "llvm/IR/Attributes.h"
#include "llvm/IR/DerivedTypes.h"
#include "llvm/IR/IRBuilder.h"
#include "llvm/IR/Intrinsics.h"
#include "llvm/IR/Metadata.h"
#include "llvm/Target/TargetMachine.h"
#include <string>

using namespace dmd;

namespace {

class TargetDirectX : public DComputeTarget {
public:
  TargetDirectX(llvm::LLVMContext &c, int smVersion)
      : DComputeTarget(c, smVersion, ID::DirectX, "directx", "dxil",
                       createDirectXABI(),
                       // Private, Global, Shared, Constant, Generic
                       // Shared → addrspace(3) (Clang group_shared / DXIL)
                       {{0, 1, 3, 2, 0}}) {

    const int major = tversion / 100;
    const int minor = (tversion % 100) / 10;
    std::string tripleString =
        "dxil-pc-shadermodel" + ldc::to_string(major) + "." +
        ldc::to_string(minor) + "-compute";

    auto floatABI = ::FloatABI::Hard;
    targetMachine = createTargetMachine(
        tripleString, "dxil", "", {}, ExplicitBitness::None, floatABI,
        llvm::Reloc::Static, llvm::CodeModel::Medium, codeGenOptLevel(), false);

    _ir = new IRState("dcomputeTargetDirectX", ctx);
#if LLVM_VERSION_MAJOR >= 21
    _ir->module.setTargetTriple(llvm::Triple(tripleString));
#else
    _ir->module.setTargetTriple(tripleString);
#endif
    _ir->module.setDataLayout(targetMachine->createDataLayout());
    _ir->dcomputetarget = this;
  }

  void addMetadata() override {
    // Module-level MD left empty initially (same as CUDA/Vulkan).
    // dxil-translate-metadata derives !dx.shaderModel from triple + fn attrs.
  }

  llvm::AttrBuilder buildKernAttrs(StructLiteralExp *kernAttr) {
    auto b = llvm::AttrBuilder(ctx);
    b.addAttribute("hlsl.shader", "compute");

    std::string numthreads = "1,1,1";
    if (kernAttr && kernAttr->elements && kernAttr->elements->length > 0) {
      if (auto *ale = (*kernAttr->elements)[0]->isArrayLiteralExp()) {
        if (ale->elements && ale->elements->length >= 3) {
          numthreads.clear();
          numthreads += ldc::to_string((*ale->elements)[0]->toInteger());
          numthreads += ",";
          numthreads += ldc::to_string((*ale->elements)[1]->toInteger());
          numthreads += ",";
          numthreads += ldc::to_string((*ale->elements)[2]->toInteger());
        }
      }
    }
    b.addAttribute("hlsl.numthreads", numthreads);
    b.addAttribute("exp-shader", "cs");
    return b;
  }

  /// Zero-arg compute entry; HLSL attrs live here (not on the D core fn).
  llvm::Function *buildWrapper(FuncDeclaration *fd) {
    auto *fty =
        llvm::FunctionType::get(llvm::Type::getVoidTy(ctx), {}, false);
    auto name = llvm::Twine(mangleExact(fd)) + llvm::Twine("_kernel");
    return llvm::Function::Create(fty, llvm::GlobalValue::ExternalLinkage, name,
                                  _ir->module);
  }

  /// Pack core parameter types into a struct (pointers → i32/i64), like Vulkan.
  llvm::StructType *buildArgStruct(llvm::Function *llf, llvm::StringRef name) {
    llvm::FunctionType *tf = llf->getFunctionType();
    llvm::SmallVector<llvm::Type *, 8> fields;
    fields.reserve(tf->getNumParams());
    const unsigned ptrBits =
        _ir->module.getDataLayout().getPointerSizeInBits();
    for (unsigned i = 0; i < tf->getNumParams(); ++i) {
      llvm::Type *t = tf->getParamType(i);
      if (t->isPointerTy())
        t = (ptrBits == 32) ? getI32Type() : getI64Type();
      fields.push_back(t);
    }
    return llvm::StructType::create(ctx, fields, name);
  }

  /// dx.RawBuffer of the arg struct — DirectX analogue of spirv.VulkanBuffer.
  /// Int params: IsWriteable=0, IsROV=0 (read-only structured buffer of args).
  llvm::TargetExtType *buildArgResourceType(llvm::Type *argStruct) {
    return llvm::TargetExtType::get(ctx, "dx.RawBuffer", {argStruct}, {0, 0});
  }

  llvm::Value *buildIntrinsicCall(llvm::IRBuilder<> &builder,
                                  llvm::StringRef dbg, llvm::StringRef name,
                                  llvm::ArrayRef<llvm::Type *> types,
                                  llvm::ArrayRef<llvm::Value *> args) {
    llvm::Function *intrinsic = llvm::Intrinsic::getOrInsertDeclaration(
        &_ir->module, llvm::Intrinsic::lookupIntrinsicID(name), types);
    return builder.CreateCall(intrinsic->getFunctionType(), intrinsic, args,
                              dbg);
  }

  /// Root signature for the arg RawBuffer SRV (t0, space0) on the wrapper entry.
  void attachArgBufferRootSignature(llvm::Function *wrapper) {
    llvm::LLVMContext &C = ctx;
    auto mdI32 = [&](int64_t v) {
      return llvm::ConstantAsMetadata::get(llvm::ConstantInt::get(
          getI32Type(), static_cast<uint64_t>(v), true));
    };
    llvm::Metadata *srvRange = llvm::MDNode::get(
        C, {llvm::MDString::get(C, "SRV"), mdI32(1), mdI32(0), mdI32(0),
            mdI32(-1), mdI32(0)});
    llvm::Metadata *descTable = llvm::MDNode::get(
        C, {llvm::MDString::get(C, "DescriptorTable"), mdI32(0), srvRange});
    llvm::Metadata *elements = llvm::MDNode::get(C, {descTable});
    llvm::Metadata *rsDef = llvm::MDNode::get(
        C, {llvm::ValueAsMetadata::get(wrapper), elements, mdI32(2)});
    _ir->module.getOrInsertNamedMetadata("dx.rootsignatures")
        ->addOperand(llvm::cast<llvm::MDNode>(rsDef));
  }

  void addKernelMetadata(FuncDeclaration *fd, llvm::Function *llf,
                         StructLiteralExp *kernAttr) override {
    // Mirror Vulkan: attrs + resource loads on a wrapper; D body stays "core".
    llvm::Function *wrapper = buildWrapper(fd);
    wrapper->addFnAttrs(buildKernAttrs(kernAttr));

    auto *bb = llvm::BasicBlock::Create(ctx, "", wrapper);
    llvm::IRBuilder<> builder(ctx);
    builder.SetInsertPoint(bb);

    llvm::FunctionType *tf = llf->getFunctionType();
    llvm::SmallVector<llvm::Value *, 8> callArgs;
    callArgs.reserve(tf->getNumParams());

    if (tf->getNumParams() != 0) {
      attachArgBufferRootSignature(wrapper);
      auto argName = (llvm::Twine(mangleExact(fd)) + "_args").str();
      llvm::StructType *argStruct = buildArgStruct(llf, argName);
      llvm::TargetExtType *resTy = buildArgResourceType(argStruct);

      llvm::Value *i32zero = llvm::ConstantInt::get(getI32Type(), 0, false);
      llvm::Value *i32one = llvm::ConstantInt::get(getI32Type(), 1, false);
      llvm::Value *nameGV = _ir->getCachedStringLiteral(argName, 0);

      // registerSpace=0, rangeLowerBound=0, rangeSize=1, index=0
      llvm::Value *handle = buildIntrinsicCall(
          builder, "handle", "llvm.dx.resource.handlefrombinding", {resTy},
          {i32zero, i32zero, i32one, i32zero, nameGV});

      llvm::Type *ptrTy = llvm::PointerType::get(ctx, /*AddressSpace=*/0);
      llvm::Value *base = buildIntrinsicCall(
          builder, "pointer", "llvm.dx.resource.getpointer",
          {ptrTy, resTy, i32zero->getType()}, {handle, i32zero});

      for (unsigned i = 0; i < tf->getNumParams(); ++i) {
        llvm::Value *gep = builder.CreateStructGEP(argStruct, base, i);
        llvm::Type *fieldTy = argStruct->getElementType(i);
        llvm::Value *loaded = builder.CreateAlignedLoad(
            fieldTy, gep, _ir->module.getDataLayout().getABITypeAlign(fieldTy),
            false);
        llvm::Type *want = tf->getParamType(i);
        if (want->isPointerTy())
          loaded = builder.CreateIntToPtr(loaded, want);
        callArgs.push_back(loaded);
      }
    }

    builder.CreateCall(tf, llf, callArgs);
    builder.CreateRetVoid();
  }
};

} // namespace

DComputeTarget *createDirectXTarget(llvm::LLVMContext &c, int smVersion) {
  return new TargetDirectX(c, smVersion);
}

#endif // LDC_LLVM_SUPPORTED_TARGET_DirectX
