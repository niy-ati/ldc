//===-- gen/dcompute/abi-rewrites.h - dcompute ABI rewrites -----*- C++ -*-===//
//
//                         LDC – the LLVM D compiler
//
// This file is distributed under the BSD-style LDC license. See the LICENSE
// file for details.
//
//===----------------------------------------------------------------------===//
//
// Contains ABI rewrites for the dcompute targets SPIR-V and NVPTX
//
//===----------------------------------------------------------------------===//

#pragma once

#include "gen/abi/generic.h"

#include "ir/irfuncty.h"

#include "llvm/IR/IntrinsicsSPIRV.h"

struct DComputePointerRewrite : ABIRewrite {
  LLValue *put(DValue *v, bool isLValueExp, bool) override {
    LLValue *address = DtoLVal(v);
    return DtoLoad(type(v->type), address, ".DComputePointerRewrite_arg");
  }

  LLValue *getLVal(Type *dty, LLValue *v) override {
    LLValue *mem = DtoAlloca(dty, ".DComputePointerRewrite_param_storage");
    LLType *realStructTy = DtoMemType(dty);
    LLValue *field = DtoGEP(realStructTy, mem, 0u, 0u);
    
    if (gIR && gIR->dcomputetarget &&
        gIR->dcomputetarget->target == DComputeTarget::ID::Vulkan) {
      auto ptrOpt = toDcomputePointer(static_cast<TypeStruct *>(dty)->sym);
      assert(ptrOpt && "DComputePointerRewrite expects ldc.dcompute.Pointer");
      const auto &ptr = *ptrOpt;
      llvm::Type *elemTy = DtoType(ptr.type);
      int realAS = gIR->dcomputetarget->mapping[ptr.addrspace];
      
      llvm::Value *ofType = llvm::PoisonValue::get(elemTy);
      llvm::Metadata *md = llvm::ValueAsMetadata::get(ofType);
      llvm::Value *mdVal = llvm::MetadataAsValue::get(gIR->context(), md);
      
#if LLVM_VERSION_MAJOR >= 20
      llvm::Function *assignFn = llvm::Intrinsic::getOrInsertDeclaration(
          &gIR->module, llvm::Intrinsic::spv_assign_ptr_type, {v->getType()});
#else
      llvm::Function *assignFn = llvm::Intrinsic::getDeclaration(
          &gIR->module, llvm::Intrinsic::spv_assign_ptr_type, {v->getType()});
#endif
      gIR->ir->CreateCall(assignFn->getFunctionType(), assignFn,
                          {v, mdVal, llvm::ConstantInt::get(llvm::Type::getInt32Ty(gIR->context()), realAS)});
    }
    if (gIR && gIR->dcomputetarget &&
        gIR->dcomputetarget->target == DComputeTarget::ID::DirectX) {
      // For DXIL Bindless, `v` is an i32 heap index. We must resolve it to a pointer.
      auto ptrOpt = toDcomputePointer(static_cast<TypeStruct *>(dty)->sym);
      llvm::Type *elemTy = DtoType(ptrOpt->type);
      
      // 1. Get the handle from the heap index
      llvm::Function *getHandleFn = llvm::Intrinsic::getOrInsertDeclaration(
          &gIR->module, llvm::Intrinsic::dx_resource_handlefromheap, {llvm::Type::getInt32Ty(gIR->context())});
      llvm::Value *handle = gIR->ir->CreateCall(getHandleFn->getFunctionType(), getHandleFn, {v}, "dxil.handle");
      
      // 2. Get the actual pointer from the handle
      llvm::Function *getPtrFn = llvm::Intrinsic::getOrInsertDeclaration(
          &gIR->module, llvm::Intrinsic::dx_resource_getpointer, {handle->getType()});
      llvm::Value *realPtr = gIR->ir->CreateCall(getPtrFn->getFunctionType(), getPtrFn, {handle}, "dxil.ptr");
      
      // Store the real pointer in the struct field so the rest of D code works normally
      DtoStore(realPtr, field);
    } else {
      DtoStore(v, field);
    }
    return mem;
  }

  LLType *type(Type *t) override {
    if (gIR && gIR->dcomputetarget &&
        gIR->dcomputetarget->target == DComputeTarget::ID::DirectX) {
      // For DXIL Bindless, pointers are passed as 32-bit indices into the heap
      return llvm::Type::getInt32Ty(gIR->context());
    }

    auto ptrOpt = toDcomputePointer(static_cast<TypeStruct *>(t)->sym);
    assert(ptrOpt && "DComputePointerRewrite expects ldc.dcompute.Pointer");
    return ptrOpt->toLLVMType(true);
  }

  void applyTo(IrFuncTyArg &arg, LLType *finalLType = nullptr) override {
    arg.rewrite = this;
    arg.ltype = finalLType ? finalLType : this->type(arg.type);
    arg.byref = false;
    arg.attrs.removeAttribute(llvm::Attribute::Dereferenceable);
    arg.attrs.removeAttribute(llvm::Attribute::NonNull);
  }
};
