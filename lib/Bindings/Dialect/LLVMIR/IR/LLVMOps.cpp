/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/Dialect/LLVMIR/LLVMDialect.h

#include "LLVMOps.h"
#include "../../../Support/BuilderBinding.h"
#include "../../../Support/CrestObject.h"
#include "../../../Support/SchemeWrapper.h"
#include "mlir/Dialect/LLVMIR/LLVMDialect.h"
#include "mlir/Dialect/LLVMIR/LLVMTypes.h"
#include "mlir/IR/Builders.h"
#include "mlir/IR/BuiltinOps.h"
#include "mlir/IR/PatternMatch.h"

namespace crest {

// Extract SmallVector<Value> from a Scheme list of Value uptrss.
static llvm::SmallVector<mlir::Value> scheme_list_to_values(ptr list) {
  llvm::SmallVector<mlir::Value> v;
  for (ptr p = list; p != Snil; p = Scdr(p)) {
    auto uval = Sunsigned64_value(Scar(p));
    v.push_back(
        mlir::Value::getFromOpaquePointer(reinterpret_cast<const void*>(uval)));
  }
  return v;
}

void registerDialectLLVMIRIRLLVMOpsBindings() {
  // mlir::LLVM::LLVMFunctionType::get: create LLVM function type i32(ptr, ...).
  // (ctx-ptr return-type-ptr param-type-ptr is-var-arg) → Type uptr
  Sregister_symbol(
      "mlir::LLVM::LLVMFunctionType::get",
      (void*)+[](uint64_t /*ctx_ptr*/, uint64_t ret_ptr, uint64_t param_ptr,
                 int is_var_arg) -> uint64_t {
        auto ret = mlir::Type::getFromOpaquePointer(
            reinterpret_cast<const void*>(ret_ptr));
        auto param = mlir::Type::getFromOpaquePointer(
            reinterpret_cast<const void*>(param_ptr));
        auto ft =
            mlir::LLVM::LLVMFunctionType::get(ret, {param}, is_var_arg != 0);
        return reinterpret_cast<uint64_t>(ft.getAsOpaquePointer());
      });

  // mlir::LLVM::LLVMPointerType::get: create opaque LLVM pointer type.
  // (ctx-ptr) → Type uptr
  Sregister_symbol(
      "mlir::LLVM::LLVMPointerType::get",
      (void*)+[](uint64_t ctx_ptr) -> uint64_t {
        auto* ctx = crest::as_ptr<mlir::MLIRContext>(
            ctx_ptr, "mlir::LLVM::LLVMPointerType::get");
        auto t = mlir::LLVM::LLVMPointerType::get(ctx);
        return reinterpret_cast<uint64_t>(t.getAsOpaquePointer());
      });

  // mlir::LLVM::LLVMArrayType::get: create LLVM array type [N x T].
  // (elem-type-ptr num-elements) → Type uptr
  Sregister_symbol(
      "mlir::LLVM::LLVMArrayType::get",
      (void*)+[](uint64_t elem_ptr, uint64_t num_elems) -> uint64_t {
        auto elem = mlir::Type::getFromOpaquePointer(
            reinterpret_cast<const void*>(elem_ptr));
        auto t = mlir::LLVM::LLVMArrayType::get(
            elem, static_cast<unsigned>(num_elems));
        return reinterpret_cast<uint64_t>(t.getAsOpaquePointer());
      });

  // mlir::LLVM::LLVMFuncOp::create: declare an LLVM function in the module.
  // (builder-ptr loc-ptr name-str func-type-ptr) → Operation* uptr
  register_builder_binding(
      "mlir::LLVM::LLVMFuncOp::create",
      [](mlir::OpBuilder& builder, uint64_t loc_ptr, const char* name,
         uint64_t ftype_ptr) -> uint64_t {
        auto loc = mlir::Location::getFromOpaquePointer(
            reinterpret_cast<const void*>(loc_ptr));
        auto ftype = mlir::cast<mlir::LLVM::LLVMFunctionType>(
            mlir::Type::getFromOpaquePointer(
                reinterpret_cast<const void*>(ftype_ptr)));
        auto op = mlir::LLVM::LLVMFuncOp::create(builder, loc, name, ftype);
        return reinterpret_cast<uint64_t>(op.getOperation());
      });

  // mlir::LLVM::GlobalOp::create: create an LLVM global constant.
  // (builder-ptr loc-ptr type-ptr is-constant linkage-int name-str
  // value-attr-ptr) → Operation* uptr linkage: 8=Internal
  register_builder_binding(
      "mlir::LLVM::GlobalOp::create",
      [](mlir::OpBuilder& builder, uint64_t loc_ptr, uint64_t type_ptr,
         int is_constant, int linkage_int, const char* name,
         uint64_t value_attr_ptr) -> uint64_t {
        auto loc = mlir::Location::getFromOpaquePointer(
            reinterpret_cast<const void*>(loc_ptr));
        auto type = mlir::Type::getFromOpaquePointer(
            reinterpret_cast<const void*>(type_ptr));
        auto value_attr = mlir::Attribute::getFromOpaquePointer(
            reinterpret_cast<const void*>(value_attr_ptr));
        auto linkage = static_cast<mlir::LLVM::Linkage>(linkage_int);
        auto op = mlir::LLVM::GlobalOp::create(builder, loc, type,
                                               is_constant != 0, linkage, name,
                                               value_attr, /*alignment=*/0);
        return reinterpret_cast<uint64_t>(op.getOperation());
      });

  // mlir::LLVM::GlobalOp::getType: return the value type of a GlobalOp.
  // (global-op-ptr) → Type uptr
  Sregister_symbol(
      "mlir::LLVM::GlobalOp::getType",
      (void*)+[](uint64_t global_op_ptr) -> uint64_t {
        auto* op = reinterpret_cast<mlir::Operation*>(global_op_ptr);
        auto global = mlir::cast<mlir::LLVM::GlobalOp>(op);
        return reinterpret_cast<uint64_t>(
            global.getType().getAsOpaquePointer());
      });

  // mlir::LLVM::AddressOfOp::create: get address of a global.
  // (builder-ptr loc-ptr global-op-ptr) → Value uptr
  register_builder_binding(
      "mlir::LLVM::AddressOfOp::create",
      [](mlir::OpBuilder& builder, uint64_t loc_ptr,
         uint64_t global_op_ptr) -> uint64_t {
        auto loc = mlir::Location::getFromOpaquePointer(
            reinterpret_cast<const void*>(loc_ptr));
        auto* op = reinterpret_cast<mlir::Operation*>(global_op_ptr);
        auto global = mlir::cast<mlir::LLVM::GlobalOp>(op);
        auto addrOp = mlir::LLVM::AddressOfOp::create(builder, loc, global);
        return reinterpret_cast<uint64_t>(
            addrOp.getResult().getAsOpaquePointer());
      });

  // mlir::LLVM::GEPOp::create: GEP into a global string to get ptr to first
  // char. (builder-ptr loc-ptr result-type-ptr elem-type-ptr ptr-val index0
  // index1) → Value uptr For global string access: result-type = ptr, elem-type
  // = array type, indices = {0, 0}
  register_builder_binding(
      "mlir::LLVM::GEPOp::create",
      [](mlir::OpBuilder& builder, uint64_t loc_ptr, uint64_t res_type_ptr,
         uint64_t elem_type_ptr, uint64_t ptr_val, uint64_t idx0,
         uint64_t idx1) -> uint64_t {
        auto loc = mlir::Location::getFromOpaquePointer(
            reinterpret_cast<const void*>(loc_ptr));
        auto res_type = mlir::Type::getFromOpaquePointer(
            reinterpret_cast<const void*>(res_type_ptr));
        auto elem_type = mlir::Type::getFromOpaquePointer(
            reinterpret_cast<const void*>(elem_type_ptr));
        auto ptr = mlir::Value::getFromOpaquePointer(
            reinterpret_cast<const void*>(ptr_val));
        auto i0 = mlir::Value::getFromOpaquePointer(
            reinterpret_cast<const void*>(idx0));
        auto i1 = mlir::Value::getFromOpaquePointer(
            reinterpret_cast<const void*>(idx1));
        llvm::SmallVector<mlir::Value> gep_indices{i0, i1};
        auto gep =
            mlir::LLVM::GEPOp::create(builder, loc, res_type, elem_type, ptr,
                                      llvm::ArrayRef<mlir::Value>(gep_indices));
        return reinterpret_cast<uint64_t>(gep.getResult().getAsOpaquePointer());
      });

  // mlir::LLVM::ConstantOp::create<i64>: create an i64 constant.
  // (builder-ptr loc-ptr int-val) → Value uptr
  register_builder_binding(
      "mlir::LLVM::ConstantOp::create<i64>",
      [](mlir::OpBuilder& builder, uint64_t loc_ptr, int64_t val) -> uint64_t {
        auto loc = mlir::Location::getFromOpaquePointer(
            reinterpret_cast<const void*>(loc_ptr));
        auto i64ty = mlir::IntegerType::get(builder.getContext(), 64);
        auto attr = builder.getI64IntegerAttr(val);
        auto op = mlir::LLVM::ConstantOp::create(builder, loc, i64ty, attr);
        return reinterpret_cast<uint64_t>(op.getResult().getAsOpaquePointer());
      });

  // mlir::LLVM::CallOp::create: call an LLVM function.
  // (builder-ptr loc-ptr func-type-ptr callee-attr-ptr operands-list) →
  // Operation* uptr operands-list: Scheme list of Value uptrss
  register_builder_binding(
      "mlir::LLVM::CallOp::create",
      [](mlir::OpBuilder& builder, uint64_t loc_ptr, uint64_t ftype_ptr,
         uint64_t callee_ptr, ptr operands_list) -> uint64_t {
        auto loc = mlir::Location::getFromOpaquePointer(
            reinterpret_cast<const void*>(loc_ptr));
        auto ftype = mlir::cast<mlir::LLVM::LLVMFunctionType>(
            mlir::Type::getFromOpaquePointer(
                reinterpret_cast<const void*>(ftype_ptr)));
        auto callee = mlir::cast<mlir::FlatSymbolRefAttr>(
            mlir::Attribute::getFromOpaquePointer(
                reinterpret_cast<const void*>(callee_ptr)));
        auto operands = scheme_list_to_values(operands_list);
        auto op =
            mlir::LLVM::CallOp::create(builder, loc, ftype, callee, operands);
        return reinterpret_cast<uint64_t>(op.getOperation());
      });

  // mlir::ModuleOp::lookupSymbol: look up a named symbol in the module.
  // (module-op-ptr name-str) → Operation* uptr (or 0 if not found)
  Sregister_symbol(
      "mlir::ModuleOp::lookupSymbol",
      (void*)+[](uint64_t op_ptr, const char* name) -> uint64_t {
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        auto module = mlir::cast<mlir::ModuleOp>(op);
        auto* sym = module.lookupSymbol(name);
        return reinterpret_cast<uint64_t>(sym);
      });

  // mlir::FlatSymbolRefAttr::get: create a flat symbol reference.
  // (ctx-ptr name-str) → Attribute uptr
  Sregister_symbol(
      "mlir::FlatSymbolRefAttr::get",
      (void*)+[](uint64_t ctx_ptr, const char* name) -> uint64_t {
        auto* ctx = crest::as_ptr<mlir::MLIRContext>(
            ctx_ptr, "mlir::FlatSymbolRefAttr::get");
        auto attr = mlir::FlatSymbolRefAttr::get(ctx, name);
        return reinterpret_cast<uint64_t>(attr.getAsOpaquePointer());
      });
}

} // namespace crest
