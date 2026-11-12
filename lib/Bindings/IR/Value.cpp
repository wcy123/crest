/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors (mlir ir value): mlir/IR/Value.h

#include "mlir/IR/Value.h"
#include "Support/Result.h"
#include "Support/SchemeWrapper.h"
#include "mlir/IR/Operation.h"

namespace crest {

void registerIRValueBindings() {
  Sregister_symbol(
      "mlir::Value::getDefiningOp", (void*)+[](uint64_t value) -> ptr {
        if (!value) {
          return scheme_error("mlir::Value::getDefiningOp",
                              "value pointer is null");
        }
        auto val = mlir::Value::getFromOpaquePointer(
            reinterpret_cast<const void*>(value));
        return Sunsigned64(reinterpret_cast<uint64_t>(val.getDefiningOp()));
      });
  Sregister_symbol(
      "mlir::Value::getUses", (void*)+[](uint64_t val_ptr) -> ptr {
        if (!val_ptr) {
          return scheme_error("mlir::Value::getUses", "value pointer is null");
        }
        auto val = mlir::Value::getFromOpaquePointer(
            reinterpret_cast<const void*>(val_ptr));
        return Sunsigned64(static_cast<uint64_t>(
            std::distance(val.use_begin(), val.use_end())));
      });
  Sregister_symbol(
      "mlir::Value::getType", (void*)+[](uint64_t value_ptr) -> ptr {
        if (!value_ptr) {
          return scheme_error("mlir::Value::getType", "value pointer is null");
        }
        auto val = mlir::Value::getFromOpaquePointer(
            reinterpret_cast<const void*>(value_ptr));
        return Sunsigned64(
            reinterpret_cast<uint64_t>(val.getType().getAsOpaquePointer()));
      });
  // Intended for type-inference passes that refine a placeholder type
  // (e.g. tensor<*xf64> → tensor<2x3xf64>) after all operand shapes are
  // known. Calling this with an incompatible type corrupts the IR silently;
  // the verifier may catch the inconsistency if it runs, but this is not
  // guaranteed.
  /// value_ptr: mlir::Value (opaque), type_ptr: mlir::Type (opaque)
  Sregister_symbol(
      "mlir::Value::setType",
      (void*)+[](uint64_t value_ptr, uint64_t type_ptr) -> ptr {
        if (!value_ptr) {
          return scheme_error("mlir::Value::setType", "value pointer is null");
        }
        auto val = mlir::Value::getFromOpaquePointer(
            reinterpret_cast<const void*>(value_ptr));
        auto type = mlir::Type::getFromOpaquePointer(
            reinterpret_cast<const void*>(type_ptr));
        val.setType(type);
        return Svoid;
      });
  /// value_ptr: mlir::Value (opaque), replacement_ptr: mlir::Value (opaque)
  Sregister_symbol(
      "mlir::Value::replaceAllUsesWith",
      (void*)+[](uint64_t value_ptr, uint64_t replacement_ptr) -> ptr {
        if (!value_ptr) {
          return scheme_error("mlir::Value::replaceAllUsesWith",
                              "value pointer is null");
        }
        auto val = mlir::Value::getFromOpaquePointer(
            reinterpret_cast<const void*>(value_ptr));
        auto repl = mlir::Value::getFromOpaquePointer(
            reinterpret_cast<const void*>(replacement_ptr));
        val.replaceAllUsesWith(repl);
        return Svoid;
      });
  Sregister_symbol(
      "mlir::BlockArgument?", (void*)+[](uint64_t value) -> ptr {
        if (!value) {
          return Sinteger64(0);
        }
        auto val = mlir::Value::getFromOpaquePointer(
            reinterpret_cast<const void*>(value));
        return Sinteger64(mlir::isa<mlir::BlockArgument>(val) ? 1 : 0);
      });
}

} // namespace crest

// ---------------------------------------------------------------------------
// mlir::OpResult - defined in mlir/IR/Value.h alongside mlir::Value.
// ---------------------------------------------------------------------------
namespace crest {
void registerIROpResultBindings() {
  Sregister_symbol(
      "mlir::OpResult::getResultNumber", (void*)+[](uint64_t value) -> ptr {
        if (!value) {
          return scheme_error("mlir::OpResult::getResultNumber",
                              "value must not be null");
        }
        auto val = mlir::Value::getFromOpaquePointer(
            reinterpret_cast<const void*>(value));
        auto result = mlir::dyn_cast<mlir::OpResult>(val);
        if (!result) {
          return scheme_error("mlir::OpResult::getResultNumber",
                              "value is not an OpResult");
        }
        return Sunsigned64(static_cast<uint64_t>(result.getResultNumber()));
      });
}
} // namespace crest
