/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/Dialect/Affine/IR/AffineOps.h

#include "AffineOps.h"
#include "../../../Support/ArrayRef.h"
#include "../../../Support/CrestObject.h"
#include "../../../Support/LockedSchemeObject.h"
#include "../../../Support/SchemeWrapper.h"
#include "mlir/Dialect/Affine/IR/AffineOps.h"
#include "mlir/Dialect/Affine/Utils.h"
#include "mlir/IR/Builders.h"
#include "mlir/IR/DialectRegistry.h"
#include "mlir/IR/PatternMatch.h"

namespace crest {

// Accept either CrestRef<RewriterBase> (from conversion patterns) or
// CrestOwned<OpBuilder> (from begin-mlir-code / buildAffineLoopNest callbacks).
static mlir::OpBuilder& get_builder(uint64_t ptr_val, const char* who) {
  auto* obj = reinterpret_cast<crest::CrestObject*>(ptr_val);
  if (obj->isa<crest::CrestRef<mlir::RewriterBase>>()) {
    return *static_cast<crest::CrestRef<mlir::RewriterBase>*>(obj)->ptr;
  }
  return crest::as_ref<mlir::OpBuilder>(ptr_val, who);
}

void registerDialectAffineIRAffineOpsBindings() {
  // buildAffineLoopNest: create a nest of affine.for loops for a given shape.
  // (builder-ptr loc-ptr shape-arr-ptr body-fn) → void
  //   shape-arr-ptr: CArrayRef<int64_t>* — ubs; lbs=0, steps=1
  //   body-fn: Scheme procedure called as (body-fn nested-builder-ptr
  //   ivs-arr-ptr)
  //     nested-builder-ptr: CrestOwned<OpBuilder>* (caller-owned, not freed by
  //     Scheme) ivs-arr-ptr:        CArrayRef<uintptr_t>* (caller-owned)
  Sregister_symbol(
      "mlir::affine::buildAffineLoopNest",
      (void*)+[](uint64_t builder_ptr, uint64_t loc_ptr, uint64_t shape_ptr,
                 ptr body_fn) -> void {
        auto& builder = get_builder(builder_ptr, "buildAffineLoopNest");
        auto loc = mlir::Location::getFromOpaquePointer(
            reinterpret_cast<const void*>(loc_ptr));
        auto* shape_arr = reinterpret_cast<CArrayRef<int64_t>*>(shape_ptr);
        size_t rank = shape_arr->size;

        llvm::SmallVector<int64_t> lbs(rank, 0);
        llvm::SmallVector<int64_t> ubs(shape_arr->data, shape_arr->data + rank);
        llvm::SmallVector<int64_t> steps(rank, 1);

        mlir::affine::buildAffineLoopNest(
            builder, loc, lbs, ubs, steps,
            [&](mlir::OpBuilder& nb, mlir::Location /*nbLoc*/,
                mlir::ValueRange ivs) {
              std::vector<uintptr_t> ptrs;
              ptrs.reserve(ivs.size());
              for (auto iv : ivs) {
                ptrs.push_back(
                    reinterpret_cast<uintptr_t>(iv.getAsOpaquePointer()));
              }
              auto iv_arr = std::make_unique<CArrayRef<uintptr_t>>(ptrs.data(),
                                                                   ptrs.size());
              crest::CrestOwned<mlir::OpBuilder> nb_shell(nb);
              scheme_call(
                  body_fn, Sunsigned64(reinterpret_cast<uint64_t>(&nb_shell)),
                  Sunsigned64(reinterpret_cast<uint64_t>(iv_arr.get())));
              nb = nb_shell.inner;
            });
      });

  // AffineLoadOp::create: load from memref at affine indices.
  // (builder-ptr loc-ptr memref-val-ptr ivs-arr-ptr) → Value uptr
  Sregister_symbol(
      "mlir::affine::AffineLoadOp::create",
      (void*)+[](uint64_t builder_ptr, uint64_t loc_ptr, uint64_t memref_ptr,
                 uint64_t ivs_ptr) -> uint64_t {
        auto& builder = crest::as_ref<mlir::OpBuilder>(
            builder_ptr, "mlir::affine::AffineLoadOp::create");
        auto loc = mlir::Location::getFromOpaquePointer(
            reinterpret_cast<const void*>(loc_ptr));
        auto memref = mlir::Value::getFromOpaquePointer(
            reinterpret_cast<const void*>(memref_ptr));
        auto* ivs_arr = reinterpret_cast<CArrayRef<uintptr_t>*>(ivs_ptr);
        llvm::SmallVector<mlir::Value> ivs;
        ivs.reserve(ivs_arr->size);
        for (size_t i = 0; i < ivs_arr->size; ++i) {
          ivs.push_back(mlir::Value::getFromOpaquePointer(
              reinterpret_cast<const void*>(ivs_arr->data[i])));
        }
        auto loaded =
            mlir::affine::AffineLoadOp::create(builder, loc, memref, ivs);
        return reinterpret_cast<uint64_t>(
            loaded.getResult().getAsOpaquePointer());
      });

  // AffineStoreOp::create: store value into memref at affine indices.
  // (builder-ptr loc-ptr value-ptr memref-val-ptr ivs-arr-ptr) → void
  Sregister_symbol(
      "mlir::affine::AffineStoreOp::create",
      (void*)+[](uint64_t builder_ptr, uint64_t loc_ptr, uint64_t value_ptr,
                 uint64_t memref_ptr, uint64_t ivs_ptr) -> void {
        auto& builder = crest::as_ref<mlir::OpBuilder>(
            builder_ptr, "mlir::affine::AffineStoreOp::create");
        auto loc = mlir::Location::getFromOpaquePointer(
            reinterpret_cast<const void*>(loc_ptr));
        auto value = mlir::Value::getFromOpaquePointer(
            reinterpret_cast<const void*>(value_ptr));
        auto memref = mlir::Value::getFromOpaquePointer(
            reinterpret_cast<const void*>(memref_ptr));
        auto* ivs_arr = reinterpret_cast<CArrayRef<uintptr_t>*>(ivs_ptr);
        llvm::SmallVector<mlir::Value> ivs;
        ivs.reserve(ivs_arr->size);
        for (size_t i = 0; i < ivs_arr->size; ++i) {
          ivs.push_back(mlir::Value::getFromOpaquePointer(
              reinterpret_cast<const void*>(ivs_arr->data[i])));
        }
        mlir::affine::AffineStoreOp::create(builder, loc, value, memref, ivs);
      });

  // Register AffineDialect into a DialectRegistry.
  // (registry-ptr) → void
  Sregister_symbol(
      "mlir::affine::AffineDialect", (void*)+[](uint64_t registry_ptr) -> void {
        crest::as_ref<mlir::DialectRegistry>(registry_ptr,
                                             "mlir::affine::AffineDialect")
            .insert<mlir::affine::AffineDialect>();
      });
}

} // namespace crest
