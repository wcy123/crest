/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/IR/AffineExpr.h

#include "AffineExpr.h"
#include "../Support/Result.h"
#include "../Support/SchemeWrapper.h"
#include "mlir/IR/AffineExpr.h"
#include "mlir/IR/MLIRContext.h"

namespace crest {

// An AffineExpr crosses the FFI as its opaque pointer
// (AffineExpr::getAsOpaquePointer). It is context-owned and valid for the
// MLIRContext lifetime; Scheme must not free it. Only the AffineExpr by
// AffineExpr form of each operator is bound; the int64_t forms are the same
// operation on getAffineConstantExpr(v).
void registerIRAffineExprBindings() {
  /// ctx_ptr: CrestBox<MLIRContext>* | MLIRContext*, position: unsigned
  Sregister_symbol(
      "mlir::getAffineDimExpr",
      (void*)+[](uint64_t ctx_ptr, uint64_t position) -> ptr {
        auto* ctx = crest::as_context(ctx_ptr);
        if (!ctx) {
          return scheme_error("mlir::getAffineDimExpr",
                              "null MLIRContext pointer");
        }
        return Sunsigned64(reinterpret_cast<uint64_t>(
            mlir::getAffineDimExpr(static_cast<unsigned>(position), ctx)
                .getAsOpaquePointer()));
      });

  Sregister_symbol(
      "mlir::getAffineSymbolExpr",
      (void*)+[](uint64_t ctx_ptr, uint64_t position) -> ptr {
        auto* ctx = crest::as_context(ctx_ptr);
        if (!ctx) {
          return scheme_error("mlir::getAffineSymbolExpr",
                              "null MLIRContext pointer");
        }
        return Sunsigned64(reinterpret_cast<uint64_t>(
            mlir::getAffineSymbolExpr(static_cast<unsigned>(position), ctx)
                .getAsOpaquePointer()));
      });

  /// ctx_ptr: CrestBox<MLIRContext>* | MLIRContext*, constant: int64_t
  Sregister_symbol(
      "mlir::getAffineConstantExpr",
      (void*)+[](uint64_t ctx_ptr, int64_t constant) -> ptr {
        auto* ctx = crest::as_context(ctx_ptr);
        if (!ctx) {
          return scheme_error("mlir::getAffineConstantExpr",
                              "null MLIRContext pointer");
        }
        return Sunsigned64(reinterpret_cast<uint64_t>(
            mlir::getAffineConstantExpr(constant, ctx).getAsOpaquePointer()));
      });

  /// expr_ptr: AffineExpr opaque pointer. Returns the raw MLIRContext*.
  Sregister_symbol(
      "mlir::AffineExpr::getContext", (void*)+[](uint64_t expr_ptr) -> ptr {
        auto expr = mlir::AffineExpr::getFromOpaquePointer(
            reinterpret_cast<const void*>(expr_ptr));
        return Sunsigned64(reinterpret_cast<uint64_t>(expr.getContext()));
      });

  Sregister_symbol(
      "mlir::AffineExpr::operator+",
      (void*)+[](uint64_t lhs_ptr, uint64_t rhs_ptr) -> ptr {
        auto lhs = mlir::AffineExpr::getFromOpaquePointer(
            reinterpret_cast<const void*>(lhs_ptr));
        auto rhs = mlir::AffineExpr::getFromOpaquePointer(
            reinterpret_cast<const void*>(rhs_ptr));
        return Sunsigned64(
            reinterpret_cast<uint64_t>((lhs + rhs).getAsOpaquePointer()));
      });

  Sregister_symbol(
      "mlir::AffineExpr::operator*",
      (void*)+[](uint64_t lhs_ptr, uint64_t rhs_ptr) -> ptr {
        auto lhs = mlir::AffineExpr::getFromOpaquePointer(
            reinterpret_cast<const void*>(lhs_ptr));
        auto rhs = mlir::AffineExpr::getFromOpaquePointer(
            reinterpret_cast<const void*>(rhs_ptr));
        return Sunsigned64(
            reinterpret_cast<uint64_t>((lhs * rhs).getAsOpaquePointer()));
      });

  Sregister_symbol(
      "mlir::AffineExpr::floorDiv",
      (void*)+[](uint64_t lhs_ptr, uint64_t rhs_ptr) -> ptr {
        auto lhs = mlir::AffineExpr::getFromOpaquePointer(
            reinterpret_cast<const void*>(lhs_ptr));
        auto rhs = mlir::AffineExpr::getFromOpaquePointer(
            reinterpret_cast<const void*>(rhs_ptr));
        return Sunsigned64(
            reinterpret_cast<uint64_t>(lhs.floorDiv(rhs).getAsOpaquePointer()));
      });

  Sregister_symbol(
      "mlir::AffineExpr::ceilDiv",
      (void*)+[](uint64_t lhs_ptr, uint64_t rhs_ptr) -> ptr {
        auto lhs = mlir::AffineExpr::getFromOpaquePointer(
            reinterpret_cast<const void*>(lhs_ptr));
        auto rhs = mlir::AffineExpr::getFromOpaquePointer(
            reinterpret_cast<const void*>(rhs_ptr));
        return Sunsigned64(
            reinterpret_cast<uint64_t>(lhs.ceilDiv(rhs).getAsOpaquePointer()));
      });

  Sregister_symbol(
      "mlir::AffineExpr::operator%",
      (void*)+[](uint64_t lhs_ptr, uint64_t rhs_ptr) -> ptr {
        auto lhs = mlir::AffineExpr::getFromOpaquePointer(
            reinterpret_cast<const void*>(lhs_ptr));
        auto rhs = mlir::AffineExpr::getFromOpaquePointer(
            reinterpret_cast<const void*>(rhs_ptr));
        return Sunsigned64(
            reinterpret_cast<uint64_t>((lhs % rhs).getAsOpaquePointer()));
      });
}

} // namespace crest
