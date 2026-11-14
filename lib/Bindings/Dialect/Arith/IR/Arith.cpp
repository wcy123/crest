/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/Dialect/Arith/IR/Arith.h

#include "Arith.h"
#include "../../../Support/BuilderBinding.h"
#include "../../../Support/CrestObject.h"
#include "../../../Support/Result.h"
#include "../../../Support/SchemeWrapper.h"
#include "mlir/Dialect/Arith/IR/Arith.h"
#include "mlir/IR/Builders.h"
#include "mlir/IR/BuiltinAttributes.h"
#include "mlir/IR/BuiltinTypes.h"
#include "mlir/IR/DialectRegistry.h"
#include "mlir/IR/PatternMatch.h"

namespace crest {

void registerDialectArithIRArithBindings() {
  // arith::AddFOp::create: floating-point addition.
  // (builder-ptr loc-ptr lhs-ptr rhs-ptr) → Value uptr
  register_builder_binding("mlir::arith::AddFOp::create",
                           [](mlir::OpBuilder& builder, uint64_t loc_ptr,
                              uint64_t lhs_ptr, uint64_t rhs_ptr) -> ptr {
                             auto loc = mlir::Location::getFromOpaquePointer(
                                 reinterpret_cast<const void*>(loc_ptr));
                             auto lhs = mlir::Value::getFromOpaquePointer(
                                 reinterpret_cast<const void*>(lhs_ptr));
                             auto rhs = mlir::Value::getFromOpaquePointer(
                                 reinterpret_cast<const void*>(rhs_ptr));
                             auto result = mlir::arith::AddFOp::create(
                                 builder, loc, lhs, rhs);
                             return Sunsigned64(reinterpret_cast<uint64_t>(
                                 result.getResult().getAsOpaquePointer()));
                           });

  // arith::MulFOp::create: floating-point multiplication.
  // (builder-ptr loc-ptr lhs-ptr rhs-ptr) → Value uptr
  register_builder_binding("mlir::arith::MulFOp::create",
                           [](mlir::OpBuilder& builder, uint64_t loc_ptr,
                              uint64_t lhs_ptr, uint64_t rhs_ptr) -> ptr {
                             auto loc = mlir::Location::getFromOpaquePointer(
                                 reinterpret_cast<const void*>(loc_ptr));
                             auto lhs = mlir::Value::getFromOpaquePointer(
                                 reinterpret_cast<const void*>(lhs_ptr));
                             auto rhs = mlir::Value::getFromOpaquePointer(
                                 reinterpret_cast<const void*>(rhs_ptr));
                             auto result = mlir::arith::MulFOp::create(
                                 builder, loc, lhs, rhs);
                             return Sunsigned64(reinterpret_cast<uint64_t>(
                                 result.getResult().getAsOpaquePointer()));
                           });

  // arith::ConstantIndexOp::create: index-type integer constant.
  // (builder-ptr loc-ptr int-val) → Value uptr
  register_builder_binding(
      "mlir::arith::ConstantIndexOp::create",
      [](mlir::OpBuilder& builder, uint64_t loc_ptr, uint64_t int_val) -> ptr {
        auto loc = mlir::Location::getFromOpaquePointer(
            reinterpret_cast<const void*>(loc_ptr));
        auto op = mlir::arith::ConstantIndexOp::create(
            builder, loc, static_cast<int64_t>(int_val));
        return Sunsigned64(
            reinterpret_cast<uint64_t>(op.getResult().getAsOpaquePointer()));
      });

  // arith::ConstantOp::create<f64>: f64 constant from a FloatAttr (TypedAttr).
  // (builder-ptr loc-ptr float-attr-ptr) → Value uptr
  register_builder_binding(
      "mlir::arith::ConstantOp::create<f64>",
      [](mlir::OpBuilder& builder, uint64_t loc_ptr, uint64_t attr_ptr) -> ptr {
        if (!loc_ptr) {
          return scheme_error("mlir::arith::ConstantOp::create<f64>",
                              "location pointer is null");
        }
        if (!attr_ptr) {
          return scheme_error("mlir::arith::ConstantOp::create<f64>",
                              "attribute pointer is null");
        }
        auto loc = mlir::Location::getFromOpaquePointer(
            reinterpret_cast<const void*>(loc_ptr));
        auto typed_attr = mlir::dyn_cast<mlir::TypedAttr>(
            mlir::Attribute::getFromOpaquePointer(
                reinterpret_cast<const void*>(attr_ptr)));
        if (!typed_attr) {
          return scheme_error("mlir::arith::ConstantOp::create<f64>",
                              "the attribute is not a typed attribute");
        }
        auto op = mlir::arith::ConstantOp::create(builder, loc, typed_attr);
        return Sunsigned64(
            reinterpret_cast<uint64_t>(op.getResult().getAsOpaquePointer()));
      });

  // Register ArithDialect into a DialectRegistry.
  Sregister_symbol(
      "mlir::DialectRegistry::insert<mlir::arith::ArithDialect>",
      (void*)+[](uint64_t registry_ptr) -> ptr {
        auto* crest_lookup1_box =
            crest::CrestBox<mlir::DialectRegistry>::inner(registry_ptr);
        if (!crest_lookup1_box) {
          return scheme_error(
              "mlir::DialectRegistry::insert<mlir::arith::ArithDialect>",
              "null pointer or not a CrestBox<mlir::DialectRegistry>");
        }
        auto& crest_lookup1 = *crest_lookup1_box;

        crest_lookup1.insert<mlir::arith::ArithDialect>();
        return Svoid;
      });
}

} // namespace crest
