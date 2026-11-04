/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/IR/AffineMap.h

#include "AffineMap.h"
#include "../Support/SchemeWrapper.h"
#include "mlir/IR/AffineMap.h"
#include "mlir/IR/MLIRContext.h"

namespace crest {

// An AffineMap crosses the FFI as its opaque pointer
// (AffineMap::getAsOpaquePointer). It is context-owned and valid for the
// MLIRContext lifetime; Scheme must not free it.
void registerIRAffineMapBindings() {
  /// ctx_ptr: CrestOwned<MLIRContext>* | MLIRContext*, num_dims: unsigned
  Sregister_symbol(
      "mlir::AffineMap::getMultiDimIdentityMap",
      (void*)+[](uint64_t ctx_ptr, uint64_t num_dims) -> uint64_t {
        auto* ctx = crest::as_ptr<mlir::MLIRContext>(
            ctx_ptr, "mlir::AffineMap::getMultiDimIdentityMap");
        return reinterpret_cast<uint64_t>(
            mlir::AffineMap::getMultiDimIdentityMap(
                static_cast<unsigned>(num_dims), ctx)
                .getAsOpaquePointer());
      });

  /// ctx_ptr: CrestOwned<MLIRContext>* | MLIRContext*, val: int64_t
  Sregister_symbol(
      "mlir::AffineMap::getConstantMap",
      (void*)+[](uint64_t ctx_ptr, int64_t val) -> uint64_t {
        auto* ctx = crest::as_ptr<mlir::MLIRContext>(
            ctx_ptr, "mlir::AffineMap::getConstantMap");
        return reinterpret_cast<uint64_t>(
            mlir::AffineMap::getConstantMap(val, ctx).getAsOpaquePointer());
      });

  /// The zero-dimension, zero-result map `() -> ()`:
  /// AffineMap::get(MLIRContext*). ctx_ptr: CrestOwned<MLIRContext>* |
  /// MLIRContext*
  Sregister_symbol(
      "mlir::AffineMap::get", (void*)+[](uint64_t ctx_ptr) -> uint64_t {
        auto* ctx =
            crest::as_ptr<mlir::MLIRContext>(ctx_ptr, "mlir::AffineMap::get");
        return reinterpret_cast<uint64_t>(
            mlir::AffineMap::get(ctx).getAsOpaquePointer());
      });
}

} // namespace crest
