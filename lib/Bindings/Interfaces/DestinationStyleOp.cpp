/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/Interfaces/DestinationStyleOpInterface.h

#include "DestinationStyleOp.h"
#include "../Support/SchemeWrapper.h"
#include "mlir/IR/Operation.h"
#include "mlir/Interfaces/DestinationStyleOpInterface.h"

extern "C" {

static int mlir_interfaces_dps_get_num_dps_inits(uint64_t op_ptr) {
  if (!op_ptr) {
    scheme_error("mlir-interfaces-dps-get-num-dps-inits",
                 "op must not be null");
  }
  mlir::Operation* op = reinterpret_cast<mlir::Operation*>(op_ptr);
  auto dpsOp = mlir::dyn_cast<mlir::DestinationStyleOpInterface>(op);
  if (!dpsOp) {
    return 0;
  }
  return static_cast<int>(dpsOp.getNumDpsInits());
}

static uint64_t mlir_interfaces_dps_get_dps_init_operand(uint64_t op_ptr,
                                                         int index) {
  if (!op_ptr) {
    scheme_error("mlir-interfaces-dps-get-dps-init-operand",
                 "op must not be null");
  }
  mlir::Operation* op = reinterpret_cast<mlir::Operation*>(op_ptr);
  auto dpsOp = mlir::dyn_cast<mlir::DestinationStyleOpInterface>(op);
  if (!dpsOp) {
    scheme_error("mlir-interfaces-dps-get-dps-init-operand",
                 "op does not implement DestinationStyleOpInterface");
  }
  if (index < 0 || index >= static_cast<int>(dpsOp.getNumDpsInits())) {
    scheme_error("mlir-interfaces-dps-get-dps-init-operand",
                 "index out of range");
  }
  return reinterpret_cast<uint64_t>(
      dpsOp.getDpsInits()[index].getAsOpaquePointer());
}

} // extern "C"

namespace crest {

void registerInterfacesDpsBindings() {
  // ── New canonical names ───────────────────────────────────────────────────
  Sregister_symbol("mlir::DestinationStyleOpInterface::getNumDpsInits",
                   (void*)::mlir_interfaces_dps_get_num_dps_inits);
  Sregister_symbol("mlir::DestinationStyleOpInterface::getDpsInitOperand",
                   (void*)::mlir_interfaces_dps_get_dps_init_operand);
}

} // namespace crest
