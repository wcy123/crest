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
  register_binding("mlir::Value::getDefiningOp",
                   [](uint64_t value) -> llvm::Expected<uint64_t> {
                     if (!value) {
                       return fail("mlir::Value::getDefiningOp",
                                   llvm::Twine("value pointer is null"));
                     }
                     auto val = mlir::Value::getFromOpaquePointer(
                         reinterpret_cast<const void*>(value));
                     return reinterpret_cast<uint64_t>(val.getDefiningOp());
                   });
  register_binding("mlir::Value::getUses",
                   [](uint64_t val_ptr) -> llvm::Expected<uint64_t> {
                     if (!val_ptr) {
                       return fail("mlir::Value::getUses",
                                   llvm::Twine("value pointer is null"));
                     }
                     auto val = mlir::Value::getFromOpaquePointer(
                         reinterpret_cast<const void*>(val_ptr));
                     return static_cast<uint64_t>(
                         std::distance(val.use_begin(), val.use_end()));
                   });
  register_binding("mlir::Value::getType",
                   [](uint64_t value_ptr) -> llvm::Expected<uint64_t> {
                     if (!value_ptr) {
                       return fail("mlir::Value::getType",
                                   llvm::Twine("value pointer is null"));
                     }
                     auto val = mlir::Value::getFromOpaquePointer(
                         reinterpret_cast<const void*>(value_ptr));
                     return reinterpret_cast<uint64_t>(
                         val.getType().getAsOpaquePointer());
                   });
  // Intended for type-inference passes that refine a placeholder type
  // (e.g. tensor<*xf64> → tensor<2x3xf64>) after all operand shapes are
  // known. Calling this with an incompatible type corrupts the IR silently;
  // the verifier may catch the inconsistency if it runs, but this is not
  // guaranteed.
  /// value_ptr: mlir::Value (opaque), type_ptr: mlir::Type (opaque)
  register_binding("mlir::Value::setType",
                   [](uint64_t value_ptr, uint64_t type_ptr) -> llvm::Error {
                     if (!value_ptr) {
                       return fail("mlir::Value::setType",
                                   llvm::Twine("value pointer is null"));
                     }
                     auto val = mlir::Value::getFromOpaquePointer(
                         reinterpret_cast<const void*>(value_ptr));
                     auto type = mlir::Type::getFromOpaquePointer(
                         reinterpret_cast<const void*>(type_ptr));
                     val.setType(type);
                     return llvm::Error::success();
                   });
  /// value_ptr: mlir::Value (opaque), replacement_ptr: mlir::Value (opaque)
  register_binding(
      "mlir::Value::replaceAllUsesWith",
      [](uint64_t value_ptr, uint64_t replacement_ptr) -> llvm::Error {
        if (!value_ptr) {
          return fail("mlir::Value::replaceAllUsesWith",
                      llvm::Twine("value pointer is null"));
        }
        auto val = mlir::Value::getFromOpaquePointer(
            reinterpret_cast<const void*>(value_ptr));
        auto repl = mlir::Value::getFromOpaquePointer(
            reinterpret_cast<const void*>(replacement_ptr));
        val.replaceAllUsesWith(repl);
        return llvm::Error::success();
      });
  register_binding("mlir::BlockArgument?", [](uint64_t value) -> int {
    if (!value) {
      return 0;
    }
    auto val =
        mlir::Value::getFromOpaquePointer(reinterpret_cast<const void*>(value));
    return mlir::isa<mlir::BlockArgument>(val) ? 1 : 0;
  });
}

} // namespace crest

// ---------------------------------------------------------------------------
// mlir::OpResult - defined in mlir/IR/Value.h alongside mlir::Value.
// ---------------------------------------------------------------------------
namespace crest {
void registerIROpResultBindings() {
  register_binding("mlir::OpResult::getResultNumber",
                   [](uint64_t value) -> llvm::Expected<uint64_t> {
                     if (!value) {
                       return fail("mlir::OpResult::getResultNumber",
                                   llvm::Twine("value must not be null"));
                     }
                     auto val = mlir::Value::getFromOpaquePointer(
                         reinterpret_cast<const void*>(value));
                     auto result = mlir::dyn_cast<mlir::OpResult>(val);
                     if (!result) {
                       return fail("mlir::OpResult::getResultNumber",
                                   llvm::Twine("value is not an OpResult"));
                     }
                     return static_cast<uint64_t>(result.getResultNumber());
                   });
}
} // namespace crest
