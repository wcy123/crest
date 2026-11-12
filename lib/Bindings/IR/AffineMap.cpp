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
  Sregister_symbol(
      "mlir::AffineMap::getMultiDimIdentityMap",
      (void*)+[](uint64_t ctx_ptr, uint64_t num_dims) -> ptr {
        auto* ctx = crest::as_context(ctx_ptr);
        if (!ctx) {
          return scheme_error("mlir::AffineMap::getMultiDimIdentityMap",
                              "null MLIRContext pointer");
        }
        return Sunsigned64(
            reinterpret_cast<uint64_t>(mlir::AffineMap::getMultiDimIdentityMap(
                                           static_cast<unsigned>(num_dims), ctx)
                                           .getAsOpaquePointer()));
      });

  /// ctx_ptr: CrestBox<MLIRContext>* | MLIRContext*, val: int64_t
  Sregister_symbol(
      "mlir::AffineMap::getConstantMap",
      (void*)+[](uint64_t ctx_ptr, int64_t val) -> ptr {
        auto* ctx = crest::as_context(ctx_ptr);
        if (!ctx) {
          return scheme_error("mlir::AffineMap::getConstantMap",
                              "null MLIRContext pointer");
        }
        return Sunsigned64(reinterpret_cast<uint64_t>(
            mlir::AffineMap::getConstantMap(val, ctx).getAsOpaquePointer()));
      });

  /// AffineMap::get(dimCount, symbolCount, results, ctx).
  /// ctx_ptr: CrestBox<MLIRContext>* | MLIRContext*, results: Scheme list of
  /// AffineExpr opaque pointers (empty for a map with no results).
  Sregister_symbol(
      "mlir::AffineMap::get",
      (void*)+[](uint64_t ctx_ptr, uint64_t dim_count, uint64_t symbol_count,
                 ptr results) -> ptr {
        auto* ctx = crest::as_context(ctx_ptr);
        if (!ctx) {
          return scheme_error("mlir::AffineMap::get",
                              "null MLIRContext pointer");
        }
        llvm::SmallVector<mlir::AffineExpr> exprs;
        for (ptr cur = results; cur != Snil; cur = Scdr(cur)) {
          exprs.push_back(mlir::AffineExpr::getFromOpaquePointer(
              reinterpret_cast<const void*>(Sunsigned64_value(Scar(cur)))));
        }
        return Sunsigned64(reinterpret_cast<uint64_t>(
            mlir::AffineMap::get(static_cast<unsigned>(dim_count),
                                 static_cast<unsigned>(symbol_count), exprs,
                                 ctx)
                .getAsOpaquePointer()));
      });
}

} // namespace crest
