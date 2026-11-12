/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/IR/AffineMap.h

#include "AffineMap.h"
#include "../Support/Result.h"
#include "../Support/SchemeWrapper.h"
#include "llvm/ADT/SmallVector.h"
#include "mlir/IR/AffineExpr.h"
#include "mlir/IR/AffineMap.h"
#include "mlir/IR/MLIRContext.h"

namespace crest {

// An AffineMap crosses the FFI as its opaque pointer
// (AffineMap::getAsOpaquePointer). It is context-owned and valid for the
// MLIRContext lifetime; Scheme must not free it.
void registerIRAffineMapBindings() {
  /// ctx_ptr: CrestBox<MLIRContext>* | MLIRContext*, num_dims: unsigned
  register_binding(
      "mlir::AffineMap::getMultiDimIdentityMap",
      [](uint64_t ctx_ptr, uint64_t num_dims) -> llvm::Expected<uint64_t> {
        CREST_TRY(ctx, crest::as_ptr<mlir::MLIRContext>(
                           ctx_ptr, "mlir::AffineMap::getMultiDimIdentityMap"));
        return reinterpret_cast<uint64_t>(
            mlir::AffineMap::getMultiDimIdentityMap(
                static_cast<unsigned>(num_dims), ctx)
                .getAsOpaquePointer());
      });

  /// ctx_ptr: CrestBox<MLIRContext>* | MLIRContext*, val: int64_t
  register_binding(
      "mlir::AffineMap::getConstantMap",
      [](uint64_t ctx_ptr, int64_t val) -> llvm::Expected<uint64_t> {
        CREST_TRY(ctx, crest::as_ptr<mlir::MLIRContext>(
                           ctx_ptr, "mlir::AffineMap::getConstantMap"));
        return reinterpret_cast<uint64_t>(
            mlir::AffineMap::getConstantMap(val, ctx).getAsOpaquePointer());
      });

  /// AffineMap::get(dimCount, symbolCount, results, ctx).
  /// ctx_ptr: CrestBox<MLIRContext>* | MLIRContext*, results: Scheme list of
  /// AffineExpr opaque pointers (empty for a map with no results).
  register_binding(
      "mlir::AffineMap::get",
      [](uint64_t ctx_ptr, uint64_t dim_count, uint64_t symbol_count,
         ptr results) -> llvm::Expected<uint64_t> {
        CREST_TRY(ctx, crest::as_ptr<mlir::MLIRContext>(
                           ctx_ptr, "mlir::AffineMap::get"));
        llvm::SmallVector<mlir::AffineExpr> exprs;
        for (ptr cur = results; cur != Snil; cur = Scdr(cur)) {
          exprs.push_back(mlir::AffineExpr::getFromOpaquePointer(
              reinterpret_cast<const void*>(Sunsigned64_value(Scar(cur)))));
        }
        return reinterpret_cast<uint64_t>(
            mlir::AffineMap::get(static_cast<unsigned>(dim_count),
                                 static_cast<unsigned>(symbol_count), exprs,
                                 ctx)
                .getAsOpaquePointer());
      });
}

} // namespace crest
