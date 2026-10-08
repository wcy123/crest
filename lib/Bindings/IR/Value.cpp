/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors (mlir ir value): mlir/IR/Value.h

#include "mlir/IR/Value.h"
#include "Support/SchemeWrapper.h"
#include "mlir/CAPI/IR.h"
#include "mlir/CAPI/Wrap.h"
#include "mlir/IR/Operation.h"

extern "C" {

// mlir::Value::getDefiningOp()
static uint64_t mlir_ir_value_get_defining_op(uint64_t value) {
  if (!value) {
    scheme_error("mlir-ir-value-get-defining-op", "value pointer is null");
  }
  MlirValue cVal{reinterpret_cast<const void*>(value)};
  return reinterpret_cast<uint64_t>(unwrap(cVal).getDefiningOp());
}

// mlir::isa<BlockArgument>(val)
static int mlir_ir_value_is_block_argument(uint64_t value) {
  if (!value) {
    scheme_error("mlir-ir-value-is-block-argument", "value pointer is null");
  }
  mlir::Value val = unwrap(MlirValue{reinterpret_cast<const void*>(value)});
  return mlir::isa<mlir::BlockArgument>(val) ? 1 : 0;
}

} // extern "C"

namespace crest {

void registerIRValueBindings() {
  Sregister_symbol("mlir::Value::getDefiningOp",
                   (void*)::mlir_ir_value_get_defining_op);
  Sregister_symbol("mlir::isa<BlockArgument>",
                   (void*)::mlir_ir_value_is_block_argument);
  Sregister_symbol(
      "mlir::Value::getUses", (void*)+[](uint64_t val_ptr) -> uint64_t {
        if (!val_ptr) {
          scheme_error("mlir::Value::getUses", "value pointer is null");
        }
        auto val = mlir::Value::getFromOpaquePointer(
            reinterpret_cast<const void*>(val_ptr));
        return static_cast<uint64_t>(
            std::distance(val.use_begin(), val.use_end()));
      });
  Sregister_symbol(
      "mlir::Value::getType", (void*)+[](uint64_t value_ptr) -> uint64_t {
        if (!value_ptr) {
          scheme_error("mlir::Value::getType", "value pointer is null");
        }
        auto val = mlir::Value::getFromOpaquePointer(
            reinterpret_cast<const void*>(value_ptr));
        return reinterpret_cast<uint64_t>(val.getType().getAsOpaquePointer());
      });
  // Alias with ? suffix (Scheme predicate convention)
  Sregister_symbol("mlir::isa<BlockArgument>?",
                   (void*)::mlir_ir_value_is_block_argument);
}

} // namespace crest
