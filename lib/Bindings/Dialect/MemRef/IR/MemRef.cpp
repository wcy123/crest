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
        auto& builder = *crest::as_raw<mlir::OpBuilder>(
            builder_ptr, "mlir::memref::AllocOp::create");
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
  // (builder-ptr loc-ptr memref-val-ptr) → Operation* uptr
  Sregister_symbol(
      "mlir::memref::DeallocOp::create",
      (void*)+[](uint64_t builder_ptr, uint64_t loc_ptr,
                 uint64_t memref_ptr) -> uint64_t {
        auto& builder = *crest::as_raw<mlir::OpBuilder>(
            builder_ptr, "mlir::memref::DeallocOp::create");
        auto loc = mlir::Location::getFromOpaquePointer(
            reinterpret_cast<const void*>(loc_ptr));
        auto memref = mlir::Value::getFromOpaquePointer(
            reinterpret_cast<const void*>(memref_ptr));
        auto dealloc = mlir::memref::DeallocOp::create(builder, loc, memref);
        return reinterpret_cast<uint64_t>(dealloc.getOperation());
      });

  // memref::LoadOp::create: load from a memref at given indices.
  // (builder-ptr loc-ptr memref-val-ptr indices-list) → Value uptr
  // indices-list: Scheme list of Value uptrss
  Sregister_symbol(
      "mlir::memref::LoadOp::create",
      (void*)+[](uint64_t builder_ptr, uint64_t loc_ptr, uint64_t memref_ptr,
                 ptr indices_list) -> uint64_t {
        auto& builder = *crest::as_raw<mlir::OpBuilder>(
            builder_ptr, "mlir::memref::LoadOp::create");
        auto loc = mlir::Location::getFromOpaquePointer(
            reinterpret_cast<const void*>(loc_ptr));
        auto memref = mlir::Value::getFromOpaquePointer(
            reinterpret_cast<const void*>(memref_ptr));
        llvm::SmallVector<mlir::Value> indices;
        for (ptr p = indices_list; p != Snil; p = Scdr(p)) {
          auto uval = Sunsigned64_value(Scar(p));
          indices.push_back(mlir::Value::getFromOpaquePointer(
              reinterpret_cast<const void*>(uval)));
        }
        auto load = mlir::memref::LoadOp::create(builder, loc, memref, indices);
        return reinterpret_cast<uint64_t>(
            load.getResult().getAsOpaquePointer());
      });

  // Register MemRefDialect into a DialectRegistry.
  Sregister_symbol(
      "mlir::memref::MemRefDialect", (void*)+[](uint64_t registry_ptr) -> void {
        crest::CrestBox<mlir::DialectRegistry>::inner(
            registry_ptr, "mlir::memref::MemRefDialect")
            .insert<mlir::memref::MemRefDialect>();
      });
}

} // namespace crest
