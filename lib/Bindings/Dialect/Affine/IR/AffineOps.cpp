/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/Dialect/Affine/IR/AffineOps.h

#include "AffineOps.h"
#include "../../../Support/CrestObject.h"
#include "../../../Support/LockedSchemeObject.h"
#include "../../../Support/SchemeWrapper.h"
#include "mlir/Dialect/Affine/IR/AffineOps.h"
#include "mlir/Dialect/Affine/Utils.h"
#include "mlir/IR/Builders.h"
#include "mlir/IR/DialectRegistry.h"
#include "mlir/IR/PatternMatch.h"

namespace crest {

// Extract a SmallVector<int64_t> from a Scheme list of fixnums.
static llvm::SmallVector<int64_t> scheme_list_to_i64(ptr list) {
  llvm::SmallVector<int64_t> v;
  for (ptr p = list; p != Snil; p = Scdr(p)) {
    v.push_back(static_cast<int64_t>(Sinteger_value(Scar(p))));
  }
  return v;
}

// Extract a SmallVector<mlir::Value> from a Scheme list of Value uptrss.
static llvm::SmallVector<mlir::Value> scheme_list_to_values(ptr list) {
  llvm::SmallVector<mlir::Value> v;
  for (ptr p = list; p != Snil; p = Scdr(p)) {
    auto uval = Sunsigned64_value(Scar(p));
    v.push_back(
        mlir::Value::getFromOpaquePointer(reinterpret_cast<const void*>(uval)));
  }
  return v;
}

void registerDialectAffineIRAffineOpsBindings() {
  // buildAffineLoopNest: create a nest of affine.for loops.
  // (builder-ptr loc-ptr shape-list body-fn) → void
  //   shape-list: Scheme list of int64 dimension sizes (lbs=0, steps=1)
  //   body-fn: (nested-builder-ptr ivs-list) → void
  //     ivs-list: Scheme list of Value uptrss (loop induction variables)
  Sregister_symbol(
      "mlir::affine::buildAffineLoopNest",
      (void*)+[](uint64_t builder_ptr, uint64_t loc_ptr, ptr shape_list,
                 ptr body_fn) -> void {
        auto& builder =
            *crest::as_ptr<mlir::OpBuilder>(builder_ptr, "buildAffineLoopNest");
        auto loc = mlir::Location::getFromOpaquePointer(
            reinterpret_cast<const void*>(loc_ptr));
        auto ubs = scheme_list_to_i64(shape_list);
        size_t rank = ubs.size();
        llvm::SmallVector<int64_t> lbs(rank, 0);
        llvm::SmallVector<int64_t> steps(rank, 1);

        mlir::affine::buildAffineLoopNest(
            builder, loc, lbs, ubs, steps,
            [&](mlir::OpBuilder& nb, mlir::Location /*nbLoc*/,
                mlir::ValueRange ivs) {
              // Pack IVs into a Scheme list of Sunsigned64-wrapped Value
              // uptrss.
              ptr iv_list = Snil;
              for (int i = static_cast<int>(ivs.size()) - 1; i >= 0; --i) {
                iv_list = Scons(
                    Sunsigned64(reinterpret_cast<uint64_t>(
                        ivs[static_cast<size_t>(i)].getAsOpaquePointer())),
                    iv_list);
              }
              crest::CrestOwned<mlir::OpBuilder> nb_shell(nb);
              scheme_call(body_fn,
                          Sunsigned64(reinterpret_cast<uint64_t>(&nb_shell)),
                          iv_list);
              nb = nb_shell.inner;
            });
      });

  // AffineLoadOp::create: load from memref at affine indices.
  // (builder-ptr loc-ptr memref-val-ptr ivs-list) → Value uptr
  //   ivs-list: Scheme list of Value uptrss (affine index variables)
  Sregister_symbol(
      "mlir::affine::AffineLoadOp::create",
      (void*)+[](uint64_t builder_ptr, uint64_t loc_ptr, uint64_t memref_ptr,
                 ptr ivs_list) -> uint64_t {
        auto& builder = *crest::as_ptr<mlir::OpBuilder>(
            builder_ptr, "mlir::affine::AffineLoadOp::create");
        auto loc = mlir::Location::getFromOpaquePointer(
            reinterpret_cast<const void*>(loc_ptr));
        auto memref = mlir::Value::getFromOpaquePointer(
            reinterpret_cast<const void*>(memref_ptr));
        auto ivs = scheme_list_to_values(ivs_list);
        auto loaded =
            mlir::affine::AffineLoadOp::create(builder, loc, memref, ivs);
        return reinterpret_cast<uint64_t>(
            loaded.getResult().getAsOpaquePointer());
      });

  // AffineStoreOp::create: store value into memref at affine indices.
  // (builder-ptr loc-ptr value-ptr memref-val-ptr ivs-list) → void
  //   ivs-list: Scheme list of Value uptrss (affine index variables)
  Sregister_symbol(
      "mlir::affine::AffineStoreOp::create",
      (void*)+[](uint64_t builder_ptr, uint64_t loc_ptr, uint64_t value_ptr,
                 uint64_t memref_ptr, ptr ivs_list) -> void {
        auto& builder = *crest::as_ptr<mlir::OpBuilder>(
            builder_ptr, "mlir::affine::AffineStoreOp::create");
        auto loc = mlir::Location::getFromOpaquePointer(
            reinterpret_cast<const void*>(loc_ptr));
        auto value = mlir::Value::getFromOpaquePointer(
            reinterpret_cast<const void*>(value_ptr));
        auto memref = mlir::Value::getFromOpaquePointer(
            reinterpret_cast<const void*>(memref_ptr));
        auto ivs = scheme_list_to_values(ivs_list);
        mlir::affine::AffineStoreOp::create(builder, loc, value, memref, ivs);
      });

  // Register AffineDialect into a DialectRegistry.
  Sregister_symbol(
      "mlir::affine::AffineDialect", (void*)+[](uint64_t registry_ptr) -> void {
        crest::as_ref<mlir::DialectRegistry>(registry_ptr,
                                             "mlir::affine::AffineDialect")
            .insert<mlir::affine::AffineDialect>();
      });
}

} // namespace crest
