/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/Dialect/MemRef/IR/MemRef.h

#include "MemRef.h"
#include "../../../Support/ArrayRef.h"
#include "../../../Support/CrestObject.h"
#include "../../../Support/SchemeWrapper.h"
#include "mlir/Dialect/MemRef/IR/MemRef.h"
#include "mlir/IR/Builders.h"
#include "mlir/IR/BuiltinTypes.h"
#include "mlir/IR/DialectRegistry.h"
#include "mlir/IR/PatternMatch.h"

namespace crest {

static mlir::OpBuilder& get_builder(uint64_t ptr_val, const char* who) {
  auto* obj = reinterpret_cast<crest::CrestObject*>(ptr_val);
  if (obj->isa<crest::CrestRef<mlir::RewriterBase>>()) {
    return *static_cast<crest::CrestRef<mlir::RewriterBase>*>(obj)->ptr;
  }
  return crest::as_ref<mlir::OpBuilder>(ptr_val, who);
}

void registerDialectMemRefIRMemRefBindings() {
  // MemRefType::get: create a MemRefType from a RankedTensorType.
  // (ranked-tensor-type-ptr) → Type uptr
  Sregister_symbol(
      "mlir::MemRefType::get",
      (void*)+[](uint64_t tensor_type_ptr) -> uint64_t {
        auto t =
            mlir::cast<mlir::RankedTensorType>(mlir::Type::getFromOpaquePointer(
                reinterpret_cast<const void*>(tensor_type_ptr)));
        auto memref_type =
            mlir::MemRefType::get(t.getShape(), t.getElementType());
        return reinterpret_cast<uint64_t>(memref_type.getAsOpaquePointer());
      });

  // memref::AllocOp::create: allocate a MemRefType on the heap.
  // (builder-ptr loc-ptr memref-type-ptr) → Value uptr (the alloc result)
  Sregister_symbol(
      "mlir::memref::AllocOp::create",
      (void*)+[](uint64_t builder_ptr, uint64_t loc_ptr,
                 uint64_t memref_type_ptr) -> uint64_t {
        auto& builder =
            get_builder(builder_ptr, "mlir::memref::AllocOp::create");
        auto loc = mlir::Location::getFromOpaquePointer(
            reinterpret_cast<const void*>(loc_ptr));
        auto memref_type =
            mlir::cast<mlir::MemRefType>(mlir::Type::getFromOpaquePointer(
                reinterpret_cast<const void*>(memref_type_ptr)));
        auto alloc = mlir::memref::AllocOp::create(builder, loc, memref_type);
        return reinterpret_cast<uint64_t>(
            alloc.getResult().getAsOpaquePointer());
      });

  // memref::DeallocOp::create: free a memref allocation.
  // (builder-ptr loc-ptr memref-val-ptr) → void
  Sregister_symbol(
      "mlir::memref::DeallocOp::create",
      (void*)+[](uint64_t builder_ptr, uint64_t loc_ptr,
                 uint64_t memref_ptr) -> void {
        auto& builder =
            get_builder(builder_ptr, "mlir::memref::DeallocOp::create");
        auto loc = mlir::Location::getFromOpaquePointer(
            reinterpret_cast<const void*>(loc_ptr));
        auto memref = mlir::Value::getFromOpaquePointer(
            reinterpret_cast<const void*>(memref_ptr));
        mlir::memref::DeallocOp::create(builder, loc, memref);
      });

  // Register MemRefDialect into a DialectRegistry.
  Sregister_symbol(
      "mlir::memref::MemRefDialect", (void*)+[](uint64_t registry_ptr) -> void {
        crest::as_ref<mlir::DialectRegistry>(registry_ptr,
                                             "mlir::memref::MemRefDialect")
            .insert<mlir::memref::MemRefDialect>();
      });
}

} // namespace crest
