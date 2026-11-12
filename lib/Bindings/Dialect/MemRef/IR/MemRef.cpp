/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/Dialect/MemRef/IR/MemRef.h

#include "MemRef.h"
#include "../../../Support/ArrayRef.h"
#include "../../../Support/BuilderBinding.h"
#include "../../../Support/CrestObject.h"
#include "../../../Support/Result.h"
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
      "mlir::MemRefType::get", (void*)+[](uint64_t tensor_type_ptr) -> ptr {
        auto t =
            mlir::cast<mlir::RankedTensorType>(mlir::Type::getFromOpaquePointer(
                reinterpret_cast<const void*>(tensor_type_ptr)));
        auto memref_type =
            mlir::MemRefType::get(t.getShape(), t.getElementType());
        return Sunsigned64(
            reinterpret_cast<uint64_t>(memref_type.getAsOpaquePointer()));
      });

  // memref::AllocOp::create: allocate a MemRefType on the heap.
  // (builder-ptr loc-ptr memref-type-ptr) → Value uptr (the alloc result)
  register_builder_binding(
      "mlir::memref::AllocOp::create",
      [](mlir::OpBuilder& builder, uint64_t loc_ptr,
         uint64_t memref_type_ptr) -> ptr {
        auto loc = mlir::Location::getFromOpaquePointer(
            reinterpret_cast<const void*>(loc_ptr));
        auto memref_type =
            mlir::cast<mlir::MemRefType>(mlir::Type::getFromOpaquePointer(
                reinterpret_cast<const void*>(memref_type_ptr)));
        auto alloc = mlir::memref::AllocOp::create(builder, loc, memref_type);
        return Sunsigned64(
            reinterpret_cast<uint64_t>(alloc.getResult().getAsOpaquePointer()));
      });

  // memref::DeallocOp::create: free a memref allocation.
  // (builder-ptr loc-ptr memref-val-ptr) → Operation* uptr
  register_builder_binding(
      "mlir::memref::DeallocOp::create",
      [](mlir::OpBuilder& builder, uint64_t loc_ptr,
         uint64_t memref_ptr) -> ptr {
        auto loc = mlir::Location::getFromOpaquePointer(
            reinterpret_cast<const void*>(loc_ptr));
        auto memref = mlir::Value::getFromOpaquePointer(
            reinterpret_cast<const void*>(memref_ptr));
        auto dealloc = mlir::memref::DeallocOp::create(builder, loc, memref);
        return Sunsigned64(reinterpret_cast<uint64_t>(dealloc.getOperation()));
      });

  // memref::LoadOp::create: load from a memref at given indices.
  // (builder-ptr loc-ptr memref-val-ptr indices-list) → Value uptr
  // indices-list: Scheme list of Value uptrss
  register_builder_binding(
      "mlir::memref::LoadOp::create",
      [](mlir::OpBuilder& builder, uint64_t loc_ptr, uint64_t memref_ptr,
         ptr indices_list) -> ptr {
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
        return Sunsigned64(
            reinterpret_cast<uint64_t>(load.getResult().getAsOpaquePointer()));
      });

  // Register MemRefDialect into a DialectRegistry.
  Sregister_symbol(
      "mlir::DialectRegistry::insert<mlir::memref::MemRefDialect>",
      (void*)+[](uint64_t registry_ptr) -> ptr {
        auto* crest_lookup1_box =
            crest::CrestBox<mlir::DialectRegistry>::inner(registry_ptr);
        if (!crest_lookup1_box) {
          return scheme_error(
              "mlir::DialectRegistry::insert<mlir::memref::MemRefDialect>",
              "null pointer or not a CrestBox<mlir::DialectRegistry>");
        }
        auto& crest_lookup1 = *crest_lookup1_box;

        crest_lookup1.insert<mlir::memref::MemRefDialect>();
        return Svoid;
      });
}

} // namespace crest
