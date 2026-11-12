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
  register_binding(
      "mlir::getAffineDimExpr",
      [](uint64_t ctx_ptr, uint64_t position) -> llvm::Expected<uint64_t> {
        CREST_TRY(ctx, crest::try_as_ptr<mlir::MLIRContext>(
                           ctx_ptr, "mlir::getAffineDimExpr"));
        return reinterpret_cast<uint64_t>(
            mlir::getAffineDimExpr(static_cast<unsigned>(position), ctx)
                .getAsOpaquePointer());
      });

  register_binding(
      "mlir::getAffineSymbolExpr",
      [](uint64_t ctx_ptr, uint64_t position) -> llvm::Expected<uint64_t> {
        CREST_TRY(ctx, crest::try_as_ptr<mlir::MLIRContext>(
                           ctx_ptr, "mlir::getAffineSymbolExpr"));
        return reinterpret_cast<uint64_t>(
            mlir::getAffineSymbolExpr(static_cast<unsigned>(position), ctx)
                .getAsOpaquePointer());
      });

  /// ctx_ptr: CrestBox<MLIRContext>* | MLIRContext*, constant: int64_t
  register_binding(
      "mlir::getAffineConstantExpr",
      [](uint64_t ctx_ptr, int64_t constant) -> llvm::Expected<uint64_t> {
        CREST_TRY(ctx, crest::try_as_ptr<mlir::MLIRContext>(
                           ctx_ptr, "mlir::getAffineConstantExpr"));
        return reinterpret_cast<uint64_t>(
            mlir::getAffineConstantExpr(constant, ctx).getAsOpaquePointer());
      });

  /// expr_ptr: AffineExpr opaque pointer. Returns the raw MLIRContext*.
  register_binding("mlir::AffineExpr::getContext",
                   [](uint64_t expr_ptr) -> uint64_t {
                     auto expr = mlir::AffineExpr::getFromOpaquePointer(
                         reinterpret_cast<const void*>(expr_ptr));
                     return reinterpret_cast<uint64_t>(expr.getContext());
                   });

  register_binding("mlir::AffineExpr::operator+",
                   [](uint64_t lhs_ptr, uint64_t rhs_ptr) -> uint64_t {
                     auto lhs = mlir::AffineExpr::getFromOpaquePointer(
                         reinterpret_cast<const void*>(lhs_ptr));
                     auto rhs = mlir::AffineExpr::getFromOpaquePointer(
                         reinterpret_cast<const void*>(rhs_ptr));
                     return reinterpret_cast<uint64_t>(
                         (lhs + rhs).getAsOpaquePointer());
                   });

  register_binding("mlir::AffineExpr::operator*",
                   [](uint64_t lhs_ptr, uint64_t rhs_ptr) -> uint64_t {
                     auto lhs = mlir::AffineExpr::getFromOpaquePointer(
                         reinterpret_cast<const void*>(lhs_ptr));
                     auto rhs = mlir::AffineExpr::getFromOpaquePointer(
                         reinterpret_cast<const void*>(rhs_ptr));
                     return reinterpret_cast<uint64_t>(
                         (lhs * rhs).getAsOpaquePointer());
                   });

  register_binding("mlir::AffineExpr::floorDiv",
                   [](uint64_t lhs_ptr, uint64_t rhs_ptr) -> uint64_t {
                     auto lhs = mlir::AffineExpr::getFromOpaquePointer(
                         reinterpret_cast<const void*>(lhs_ptr));
                     auto rhs = mlir::AffineExpr::getFromOpaquePointer(
                         reinterpret_cast<const void*>(rhs_ptr));
                     return reinterpret_cast<uint64_t>(
                         lhs.floorDiv(rhs).getAsOpaquePointer());
                   });

  register_binding("mlir::AffineExpr::ceilDiv",
                   [](uint64_t lhs_ptr, uint64_t rhs_ptr) -> uint64_t {
                     auto lhs = mlir::AffineExpr::getFromOpaquePointer(
                         reinterpret_cast<const void*>(lhs_ptr));
                     auto rhs = mlir::AffineExpr::getFromOpaquePointer(
                         reinterpret_cast<const void*>(rhs_ptr));
                     return reinterpret_cast<uint64_t>(
                         lhs.ceilDiv(rhs).getAsOpaquePointer());
                   });

  register_binding("mlir::AffineExpr::operator%",
                   [](uint64_t lhs_ptr, uint64_t rhs_ptr) -> uint64_t {
                     auto lhs = mlir::AffineExpr::getFromOpaquePointer(
                         reinterpret_cast<const void*>(lhs_ptr));
                     auto rhs = mlir::AffineExpr::getFromOpaquePointer(
                         reinterpret_cast<const void*>(rhs_ptr));
                     return reinterpret_cast<uint64_t>(
                         (lhs % rhs).getAsOpaquePointer());
                   });
}

} // namespace crest
