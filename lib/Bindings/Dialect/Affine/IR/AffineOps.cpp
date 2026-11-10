/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/Dialect/Affine/IR/AffineOps.h

#include "AffineOps.h"
#include "../../../Support/BuilderBinding.h"
#include "../../../Support/CrestObject.h"
#include "../../../Support/ForeignCallable.h"
#include "../../../Support/SchemeWrapper.h"
#include "mlir/Dialect/Affine/IR/AffineOps.h"
#include "mlir/Dialect/Affine/Utils.h"
#include "mlir/IR/AffineMap.h"
#include "mlir/IR/Builders.h"
#include "mlir/IR/DialectRegistry.h"

namespace crest {

void registerDialectAffineIRAffineOpsBindings() {
  // mlir::affine::buildAffineLoopNest(OpBuilder&, Location, lbs, ubs, steps,
  // body) (builder loc lbs ubs steps body-fn) → void
  //   lbs, ubs, steps: Scheme lists of integers
  //   body-fn: a Scheme procedure, made into a foreign-callable for this call,
  //   (nested-builder loc ivs count) → void, the callback of the C++ function
  //     nested-builder: builder shell, valid only during the call
  //     ivs: pointer to the Value uptrs (the induction variables), and count
  register_builder_binding(
      "mlir::affine::buildAffineLoopNest",
      [](mlir::OpBuilder& builder, uint64_t loc_ptr, ptr lbs, ptr ubs,
         ptr steps, ptr body_fn) -> void {
        // Making the callable runs Scheme, which can move the lists: read them
        // first. The owner releases the callable when the call is over.
        auto lowerBounds = convert_to_cpp<llvm::SmallVector<int64_t>>(lbs);
        auto upperBounds = convert_to_cpp<llvm::SmallVector<int64_t>>(ubs);
        auto stepValues = convert_to_cpp<llvm::SmallVector<int64_t>>(steps);
        auto owned =
            crest::ForeignCallable<void(uint64_t, uint64_t, const uint64_t*,
                                        uint64_t)>::fromProcedure(body_fn);
        auto loc = mlir::Location::getFromOpaquePointer(
            reinterpret_cast<const void*>(loc_ptr));
        mlir::affine::buildAffineLoopNest(
            builder, loc, lowerBounds, upperBounds, stepValues,
            [&](mlir::OpBuilder& nb, mlir::Location nb_loc,
                mlir::ValueRange ivs) {
              // Borrowed shell, valid for the duration of the call.
              crest::CrestBox<mlir::OpBuilder*> nb_shell(&nb);
              llvm::SmallVector<uint64_t, 4> iv_pointers;
              for (mlir::Value iv : ivs) {
                iv_pointers.push_back(
                    reinterpret_cast<uint64_t>(iv.getAsOpaquePointer()));
              }
              owned(reinterpret_cast<uint64_t>(&nb_shell),
                    reinterpret_cast<uint64_t>(nb_loc.getAsOpaquePointer()),
                    iv_pointers.data(), iv_pointers.size());
            });
      });

  // AffineLoadOp::create(OpBuilder&, Location, Value memref, ValueRange
  // indices) (builder loc memref indices) → Value uptr
  //   indices: Scheme list of Value uptrs
  register_builder_binding(
      "mlir::affine::AffineLoadOp::create",
      [](mlir::OpBuilder& builder, uint64_t loc_ptr, uint64_t memref_ptr,
         ptr indices) -> uint64_t {
        auto loc = mlir::Location::getFromOpaquePointer(
            reinterpret_cast<const void*>(loc_ptr));
        auto memref = mlir::Value::getFromOpaquePointer(
            reinterpret_cast<const void*>(memref_ptr));
        auto loaded = mlir::affine::AffineLoadOp::create(
            builder, loc, memref,
            convert_to_cpp<llvm::SmallVector<mlir::Value>>(indices));
        return reinterpret_cast<uint64_t>(
            loaded.getResult().getAsOpaquePointer());
      });

  // AffineStoreOp::create(OpBuilder&, Location, Value value, Value memref,
  //                       ValueRange indices)
  // (builder loc value memref indices) → void
  //   indices: Scheme list of Value uptrs
  register_builder_binding(
      "mlir::affine::AffineStoreOp::create",
      [](mlir::OpBuilder& builder, uint64_t loc_ptr, uint64_t value_ptr,
         uint64_t memref_ptr, ptr indices) -> void {
        auto loc = mlir::Location::getFromOpaquePointer(
            reinterpret_cast<const void*>(loc_ptr));
        auto value = mlir::Value::getFromOpaquePointer(
            reinterpret_cast<const void*>(value_ptr));
        auto memref = mlir::Value::getFromOpaquePointer(
            reinterpret_cast<const void*>(memref_ptr));
        mlir::affine::AffineStoreOp::create(
            builder, loc, value, memref,
            convert_to_cpp<llvm::SmallVector<mlir::Value>>(indices));
      });

  // AffineLoadOp::create(OpBuilder&, Location, Value memref, AffineMap map,
  //                      ValueRange mapOperands)
  // (builder loc memref map map-operands) → Value uptr
  //   map: AffineMap opaque pointer; map-operands: Scheme list of Value uptrs
  register_builder_binding(
      "mlir::affine::AffineLoadOp::create<AffineMap>",
      [](mlir::OpBuilder& builder, uint64_t loc_ptr, uint64_t memref_ptr,
         uint64_t map_ptr, ptr map_operands) -> uint64_t {
        auto loc = mlir::Location::getFromOpaquePointer(
            reinterpret_cast<const void*>(loc_ptr));
        auto memref = mlir::Value::getFromOpaquePointer(
            reinterpret_cast<const void*>(memref_ptr));
        auto map = mlir::AffineMap::getFromOpaquePointer(
            reinterpret_cast<const void*>(map_ptr));
        auto loaded = mlir::affine::AffineLoadOp::create(
            builder, loc, memref, map,
            convert_to_cpp<llvm::SmallVector<mlir::Value>>(map_operands));
        return reinterpret_cast<uint64_t>(
            loaded.getResult().getAsOpaquePointer());
      });

  // AffineStoreOp::create(OpBuilder&, Location, Value value, Value memref,
  //                       AffineMap map, ValueRange mapOperands)
  // (builder loc value memref map map-operands) → void
  //   map: AffineMap opaque pointer; map-operands: Scheme list of Value uptrs
  register_builder_binding(
      "mlir::affine::AffineStoreOp::create<AffineMap>",
      [](mlir::OpBuilder& builder, uint64_t loc_ptr, uint64_t value_ptr,
         uint64_t memref_ptr, uint64_t map_ptr, ptr map_operands) -> void {
        auto loc = mlir::Location::getFromOpaquePointer(
            reinterpret_cast<const void*>(loc_ptr));
        auto value = mlir::Value::getFromOpaquePointer(
            reinterpret_cast<const void*>(value_ptr));
        auto memref = mlir::Value::getFromOpaquePointer(
            reinterpret_cast<const void*>(memref_ptr));
        auto map = mlir::AffineMap::getFromOpaquePointer(
            reinterpret_cast<const void*>(map_ptr));
        mlir::affine::AffineStoreOp::create(
            builder, loc, value, memref, map,
            convert_to_cpp<llvm::SmallVector<mlir::Value>>(map_operands));
      });

  // Register AffineDialect into a DialectRegistry.
  Sregister_symbol(
      "mlir::DialectRegistry::insert<mlir::affine::AffineDialect>",
      (void*)+[](uint64_t registry_ptr) -> void {
        crest::CrestBox<mlir::DialectRegistry>::inner(
            registry_ptr,
            "mlir::DialectRegistry::insert<mlir::affine::AffineDialect>")
            .insert<mlir::affine::AffineDialect>();
      });
}

} // namespace crest
