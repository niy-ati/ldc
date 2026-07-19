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
// Kernel ABI: D @kernel is a "core" function; zero-arg wrapper (*_kernel)
// carries hlsl.* attrs. Pointer args are bound as writable dx.RawBuffer
// (UAV) + getpointer — matching llvm/test/CodeGen/DirectX/ResourceAccess —
// and the core is AlwaysInline so resource-access can rewrite stores.
// Non-pointer args stay in a read-only arg RawBuffer (SRV), Vulkan-style.
//
//===----------------------------------------------------------------------===//

#if LDC_LLVM_SUPPORTED_TARGET_DirectX

#include "dmd/expression.h"
#include "dmd/mangle.h"
#include "gen/abi/targets.h"
#include "gen/dcompute/druntime.h"
#include "gen/dcompute/target.h"
#include "dmd/declaration.h"
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
#include "llvm/IR/PassManager.h"
#include "llvm/Passes/PassBuilder.h"
#include "llvm/Analysis/CGSCCPassManager.h"
#include "llvm/Analysis/LoopAnalysisManager.h"
#include "llvm/Target/TargetMachine.h"
#include "llvm/Transforms/IPO/AlwaysInliner.h"
#include "llvm/Transforms/Utils/Mem2Reg.h"
#include <string>

using namespace dmd;

namespace {

class TargetDirectX : public DComputeTarget {
public:
  TargetDirectX(llvm::LLVMContext &c, int smVersion)
      : DComputeTarget(c, smVersion, ID::DirectX, "directx", "dxil",
                       createDirectXABI(),
                       // Private, Global, Shared, Constant, Generic
                       // Global → AS0: DX buffer traffic is resource getpointer
                       // (default AS), not CUDA-style AS1. Shared → AS3.
                       {{0, 0, 3, 2, 0}}) {

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

  /// Inline AlwaysInline cores into wrappers, then mem2reg.
  /// DXIL Resource Access crashes (and cannot rewrite stores) when
  /// getpointer is stashed through a D Pointer alloca/reload; after mem2reg
  /// the store uses the getpointer result directly (LLVM test shape).
  void prepareModuleForDXIL() {
    llvm::PassBuilder PB;
    llvm::LoopAnalysisManager LAM;
    llvm::FunctionAnalysisManager FAM;
    llvm::CGSCCAnalysisManager CGAM;
    llvm::ModuleAnalysisManager MAM;
    PB.registerModuleAnalyses(MAM);
    PB.registerCGSCCAnalyses(CGAM);
    PB.registerFunctionAnalyses(FAM);
    PB.registerLoopAnalyses(LAM);
    PB.crossRegisterProxies(LAM, FAM, CGAM, MAM);

    llvm::ModulePassManager MPM;
    MPM.addPass(llvm::AlwaysInlinerPass());
    llvm::FunctionPassManager FPM;
    FPM.addPass(llvm::PromotePass());
    MPM.addPass(llvm::createModuleToFunctionPassAdaptor(std::move(FPM)));
    MPM.run(_ir->module, MAM);
  }

  void addMetadata() override {
    // LLVM's DXContainerGlobals always writes PSV0 at RuntimeInfoSize=52 (v3).
    // Microsoft dxv derives the *expected* size from !dx.valver via
    // GetPSVVersion(ValMajor, ValMinor). Missing valver ⇒ default 1.0 ⇒
    // expected size 24 ⇒ "PSVRuntimeInfoSize 52 vs 24".
    // Validator 1.8 is the floor for PSV v3 (EntryFunctionName); DXC for
    // cs_6_6 currently emits 1.9. Either satisfies size 52.
    // Ref: DxilContainerValidation.cpp VerifyPSVMatches; empirically
    // llvm_minimal_uav_store.ll validates only after !dx.valver={1,8}.
    llvm::IRBuilder<> IRB(ctx);
    auto *major = llvm::ConstantAsMetadata::get(IRB.getInt32(1));
    auto *minor = llvm::ConstantAsMetadata::get(IRB.getInt32(8));
    llvm::NamedMDNode *valver = _ir->module.getOrInsertNamedMetadata("dx.valver");
    valver->clearOperands();
    valver->addOperand(llvm::MDNode::get(ctx, {major, minor}));

    prepareModuleForDXIL();
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

  /// Read-only arg pack (non-pointer params) — IsWriteable=0, IsROV=0.
  llvm::TargetExtType *buildArgResourceType(llvm::Type *argStruct) {
    return llvm::TargetExtType::get(ctx, "dx.RawBuffer", {argStruct}, {0, 0});
  }

  /// Writable buffer for a pointer param — same shape as store_rawbuffer.ll
  /// (element type, IsWriteable=1, IsROV=0, [, extra 0 for 4-param form]).
  llvm::TargetExtType *buildPointerResourceType(llvm::Type *elemTy) {
    return llvm::TargetExtType::get(ctx, "dx.RawBuffer", {elemTy}, {1, 0, 0});
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

  void attachRootSignature(llvm::Function *wrapper, bool hasUav, bool hasSrv) {
    if (!hasUav && !hasSrv)
      return;
    llvm::LLVMContext &C = ctx;
    auto mdI32 = [&](int64_t v) {
      return llvm::ConstantAsMetadata::get(llvm::ConstantInt::get(
          getI32Type(), static_cast<uint64_t>(v), true));
    };
    llvm::SmallVector<llvm::Metadata *, 2> ranges;
    // UAV u0 for pointer buffers; SRV t0 for arg pack (if both, u0 + t0).
    if (hasUav)
      ranges.push_back(llvm::MDNode::get(
          C, {llvm::MDString::get(C, "UAV"), mdI32(1), mdI32(0), mdI32(0),
              mdI32(-1), mdI32(0)}));
    if (hasSrv)
      ranges.push_back(llvm::MDNode::get(
          C, {llvm::MDString::get(C, "SRV"), mdI32(1), mdI32(0), mdI32(0),
              mdI32(-1), mdI32(0)}));
    llvm::SmallVector<llvm::Metadata *, 4> tableOps;
    tableOps.push_back(llvm::MDString::get(C, "DescriptorTable"));
    tableOps.push_back(mdI32(0));
    tableOps.append(ranges.begin(), ranges.end());
    llvm::Metadata *descTable = llvm::MDNode::get(C, tableOps);
    llvm::Metadata *elements = llvm::MDNode::get(C, {descTable});
    llvm::Metadata *rsDef = llvm::MDNode::get(
        C, {llvm::ValueAsMetadata::get(wrapper), elements, mdI32(2)});
    _ir->module.getOrInsertNamedMetadata("dx.rootsignatures")
        ->addOperand(llvm::cast<llvm::MDNode>(rsDef));
  }

  /// Element type for a dcompute Pointer / raw pointer param.
  llvm::Type *guessPointerElemType(Type *t) {
    if (!t)
      return llvm::Type::getFloatTy(ctx);
    t = t->toBasetype();
    if (auto *ts = t->isTypeStruct()) {
      if (auto dcp = toDcomputePointer(ts->sym))
        return DtoType(dcp->type);
    }
    if (t->ty == TY::Tpointer || t->ty == TY::Treference)
      return DtoType(t->nextOf());
    return llvm::Type::getFloatTy(ctx);
  }

  void addKernelMetadata(FuncDeclaration *fd, llvm::Function *llf,
                         StructLiteralExp *kernAttr) override {
    // Attrs + resource ops on wrapper; core stays the D body (AlwaysInline so
    // getpointer + store meet in one function after inlining — DXIL tests).
    llvm::Function *wrapper = buildWrapper(fd);
    wrapper->addFnAttrs(buildKernAttrs(kernAttr));
    llf->addFnAttr(llvm::Attribute::AlwaysInline);
    llf->setLinkage(llvm::GlobalValue::InternalLinkage);

    auto *bb = llvm::BasicBlock::Create(ctx, "", wrapper);
    llvm::IRBuilder<> builder(ctx);
    builder.SetInsertPoint(bb);

    llvm::FunctionType *tf = llf->getFunctionType();
    llvm::SmallVector<llvm::Value *, 8> callArgs;
    callArgs.reserve(tf->getNumParams());

    llvm::Value *i32zero = llvm::ConstantInt::get(getI32Type(), 0, false);
    llvm::Value *i32one = llvm::ConstantInt::get(getI32Type(), 1, false);
    llvm::Type *ptrTy = llvm::PointerType::get(ctx, /*AddressSpace=*/0);

    unsigned uavReg = 0;
    bool hasUav = false;
    bool hasSrv = false;

    // Non-pointer params packed into SRV arg buffer (register t0).
    llvm::SmallVector<unsigned, 8> nonPtrIndices;
    for (unsigned i = 0; i < tf->getNumParams(); ++i) {
      if (!tf->getParamType(i)->isPointerTy())
        nonPtrIndices.push_back(i);
    }

    llvm::Value *argBase = nullptr;
    llvm::StructType *argStruct = nullptr;
    if (!nonPtrIndices.empty()) {
      hasSrv = true;
      auto argName = (llvm::Twine(mangleExact(fd)) + "_args").str();
      llvm::SmallVector<llvm::Type *, 8> fields;
      for (unsigned idx : nonPtrIndices)
        fields.push_back(tf->getParamType(idx));
      argStruct = llvm::StructType::create(ctx, fields, argName);
      llvm::TargetExtType *resTy = buildArgResourceType(argStruct);
      llvm::Value *nameGV = _ir->getCachedStringLiteral(argName, 0);
      llvm::Value *handle = buildIntrinsicCall(
          builder, "arg_handle", "llvm.dx.resource.handlefrombinding", {resTy},
          {i32zero, i32zero, i32one, i32zero, nameGV});
      argBase = buildIntrinsicCall(
          builder, "arg_pointer", "llvm.dx.resource.getpointer",
          {ptrTy, resTy, i32zero->getType()}, {handle, i32zero});
    }

    unsigned nonPtrSlot = 0;
    VarDeclarations *params = fd->parameters;
    for (unsigned i = 0; i < tf->getNumParams(); ++i) {
      llvm::Type *want = tf->getParamType(i);
      if (want->isPointerTy()) {
        hasUav = true;
        Type *dty =
            (params && i < params->length) ? (*params)[i]->type : nullptr;
        llvm::Type *elemTy = guessPointerElemType(dty);
        llvm::TargetExtType *resTy = buildPointerResourceType(elemTy);
        // Name ptr null — same as llvm/test/.../store_rawbuffer.ll.
        llvm::Value *nameNull = llvm::ConstantPointerNull::get(
            llvm::PointerType::get(ctx, /*AddressSpace=*/0));
        // space=0, register=uavReg, rangeSize=1, index=0
        llvm::Value *reg =
            llvm::ConstantInt::get(getI32Type(), uavReg, false);
        llvm::Value *handle = buildIntrinsicCall(
            builder, "uav_handle", "llvm.dx.resource.handlefrombinding",
            {resTy}, {i32zero, reg, i32one, i32zero, nameNull});
        llvm::Value *base = buildIntrinsicCall(
            builder, "uav_pointer", "llvm.dx.resource.getpointer",
            {ptrTy, resTy, i32zero->getType()}, {handle, i32zero});
        callArgs.push_back(base);
        ++uavReg;
      } else {
        assert(argBase && argStruct);
        llvm::Value *gep =
            builder.CreateStructGEP(argStruct, argBase, nonPtrSlot++);
        llvm::Type *fieldTy = gep->getType(); // opaque; load uses struct field
        fieldTy = argStruct->getElementType(nonPtrSlot - 1);
        llvm::Value *loaded = builder.CreateAlignedLoad(
            fieldTy, gep, _ir->module.getDataLayout().getABITypeAlign(fieldTy),
            false);
        callArgs.push_back(loaded);
      }
    }

    if (tf->getNumParams() != 0)
      attachRootSignature(wrapper, hasUav, hasSrv);

    builder.CreateCall(tf, llf, callArgs);
    builder.CreateRetVoid();
  }
};

} // namespace

DComputeTarget *createDirectXTarget(llvm::LLVMContext &c, int smVersion) {
  return new TargetDirectX(c, smVersion);
}

#endif // LDC_LLVM_SUPPORTED_TARGET_DirectX
