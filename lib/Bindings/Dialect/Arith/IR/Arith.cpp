/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/Dialect/Arith/IR/Arith.h

#include "Arith.h"
#include "../../../Support/CrestObject.h"
#include "../../../Support/SchemeWrapper.h"
#include "mlir/Dialect/Arith/IR/Arith.h"
#include "mlir/IR/Builders.h"
#include "mlir/IR/BuiltinAttributes.h"
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

void registerDialectArithIRArithBindings() {
  // arith::AddFOp::create: floating-point addition.
  // (builder-ptr loc-ptr lhs-ptr rhs-ptr) → Value uptr
  Sregister_symbol(
      "mlir::arith::AddFOp::create",
      (void*)+[](uint64_t builder_ptr, uint64_t loc_ptr, uint64_t lhs_ptr,
                 uint64_t rhs_ptr) -> uint64_t {
        auto& builder = get_builder(builder_ptr, "mlir::arith::AddFOp::create");
        auto loc = mlir::Location::getFromOpaquePointer(
            reinterpret_cast<const void*>(loc_ptr));
        auto lhs = mlir::Value::getFromOpaquePointer(
            reinterpret_cast<const void*>(lhs_ptr));
        auto rhs = mlir::Value::getFromOpaquePointer(
            reinterpret_cast<const void*>(rhs_ptr));
        auto result = mlir::arith::AddFOp::create(builder, loc, lhs, rhs);
        return reinterpret_cast<uint64_t>(
            result.getResult().getAsOpaquePointer());
      });

  // arith::MulFOp::create: floating-point multiplication.
  // (builder-ptr loc-ptr lhs-ptr rhs-ptr) → Value uptr
  Sregister_symbol(
      "mlir::arith::MulFOp::create",
      (void*)+[](uint64_t builder_ptr, uint64_t loc_ptr, uint64_t lhs_ptr,
                 uint64_t rhs_ptr) -> uint64_t {
        auto& builder = get_builder(builder_ptr, "mlir::arith::MulFOp::create");
        auto loc = mlir::Location::getFromOpaquePointer(
            reinterpret_cast<const void*>(loc_ptr));
        auto lhs = mlir::Value::getFromOpaquePointer(
            reinterpret_cast<const void*>(lhs_ptr));
        auto rhs = mlir::Value::getFromOpaquePointer(
            reinterpret_cast<const void*>(rhs_ptr));
        auto result = mlir::arith::MulFOp::create(builder, loc, lhs, rhs);
        return reinterpret_cast<uint64_t>(
            result.getResult().getAsOpaquePointer());
      });

  // arith::ConstantIndexOp::create: index-type integer constant.
  // (builder-ptr loc-ptr int-val) → Value uptr
  Sregister_symbol(
      "mlir::arith::ConstantIndexOp::create",
      (void*)+[](uint64_t builder_ptr, uint64_t loc_ptr,
                 uint64_t int_val) -> uint64_t {
        auto& builder =
            get_builder(builder_ptr, "mlir::arith::ConstantIndexOp::create");
        auto loc = mlir::Location::getFromOpaquePointer(
            reinterpret_cast<const void*>(loc_ptr));
        auto op = mlir::arith::ConstantIndexOp::create(
            builder, loc, static_cast<int64_t>(int_val));
        return reinterpret_cast<uint64_t>(op.getResult().getAsOpaquePointer());
      });

  // arith::ConstantOp::create<f64>: f64 constant from a FloatAttr (TypedAttr).
  // (builder-ptr loc-ptr float-attr-ptr) → Value uptr
  Sregister_symbol(
      "mlir::arith::ConstantOp::create<f64>",
      (void*)+[](uint64_t builder_ptr, uint64_t loc_ptr,
                 uint64_t attr_ptr) -> uint64_t {
        auto& builder =
            get_builder(builder_ptr, "mlir::arith::ConstantOp::create<f64>");
        auto loc = mlir::Location::getFromOpaquePointer(
            reinterpret_cast<const void*>(loc_ptr));
        auto typed_attr =
            mlir::cast<mlir::TypedAttr>(mlir::Attribute::getFromOpaquePointer(
                reinterpret_cast<const void*>(attr_ptr)));
        auto op = mlir::arith::ConstantOp::create(builder, loc, typed_attr);
        return reinterpret_cast<uint64_t>(op.getResult().getAsOpaquePointer());
      });

  // Register ArithDialect into a DialectRegistry.
  Sregister_symbol(
      "mlir::arith::ArithDialect", (void*)+[](uint64_t registry_ptr) -> void {
        crest::as_ref<mlir::DialectRegistry>(registry_ptr,
                                             "mlir::arith::ArithDialect")
            .insert<mlir::arith::ArithDialect>();
      });
}

} // namespace crest
