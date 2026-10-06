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

static void scheme_error(const char* who, const char* msg) {
  Scall2(Stop_level_value(Sstring_to_symbol("error")), Sstring(who),
         Sstring(msg));
}

extern "C" {

// mlir::Value::getDefiningOp()
static uint64_t mlir_ir_value_get_defining_op(uint64_t value) {
  if (!value) {
    scheme_error("mlir-ir-value-get-defining-op", "value pointer is null");
    return 0; // unreachable — error performs non-local exit
  }
  MlirValue cVal{reinterpret_cast<const void*>(value)};
  return reinterpret_cast<uint64_t>(unwrap(cVal).getDefiningOp());
}

// mlir::isa<BlockArgument>(val)
static int mlir_ir_value_is_block_argument(uint64_t value) {
  if (!value) {
    scheme_error("mlir-ir-value-is-block-argument", "value pointer is null");
    return 0; // unreachable — error performs non-local exit
  }
  mlir::Value val = unwrap(MlirValue{reinterpret_cast<const void*>(value)});
  return mlir::isa<mlir::BlockArgument>(val) ? 1 : 0;
}

// mlir::Value::use_begin/use_end (count)
static uint64_t mlir_ir_value_num_uses(uint64_t val_ptr) {
  if (!val_ptr) {
    scheme_error("mlir-ir-value-num-uses", "value pointer is null");
    return 0; // unreachable — error performs non-local exit
  }
  auto val =
      mlir::Value::getFromOpaquePointer(reinterpret_cast<const void*>(val_ptr));
  return static_cast<uint64_t>(std::distance(val.use_begin(), val.use_end()));
}

// mlir::Value::getType()
static uint64_t mlir_ir_value_get_type(uint64_t value_ptr) {
  if (!value_ptr) {
    scheme_error("mlir-ir-value-get-type", "value pointer is null");
    return 0; // unreachable — error performs non-local exit
  }
  auto val = mlir::Value::getFromOpaquePointer(
      reinterpret_cast<const void*>(value_ptr));
  return reinterpret_cast<uint64_t>(val.getType().getAsOpaquePointer());
}

} // extern "C"

namespace crest {

void registerIRValueBindings() {
  Sregister_symbol("mlir::Value::getDefiningOp",
                   (void*)::mlir_ir_value_get_defining_op);
  Sregister_symbol("mlir::isa<BlockArgument>",
                   (void*)::mlir_ir_value_is_block_argument);
  Sregister_symbol("mlir::Value::getUses", (void*)::mlir_ir_value_num_uses);
  Sregister_symbol("mlir::Value::getType", (void*)::mlir_ir_value_get_type);
  // Alias with ? suffix (Scheme predicate convention)
  Sregister_symbol("mlir::isa<BlockArgument>?",
                   (void*)::mlir_ir_value_is_block_argument);
}

} // namespace crest
