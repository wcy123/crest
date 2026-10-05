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

int mlir_interfaces_dps_get_num_dps_inits(uint64_t op_ptr) {
  if (!op_ptr) {
    return 0;
  }
  mlir::Operation* op = reinterpret_cast<mlir::Operation*>(op_ptr);
  auto dpsOp = mlir::dyn_cast<mlir::DestinationStyleOpInterface>(op);
  if (!dpsOp) {
    return 0;
  }
  return static_cast<int>(dpsOp.getNumDpsInits());
}

uint64_t mlir_interfaces_dps_get_dps_init_value(uint64_t op_ptr, int index) {
  if (!op_ptr) {
    return 0;
  }
  mlir::Operation* op = reinterpret_cast<mlir::Operation*>(op_ptr);
  auto dpsOp = mlir::dyn_cast<mlir::DestinationStyleOpInterface>(op);
  if (!dpsOp) {
    return 0;
  }
  if (index < 0 || index >= static_cast<int>(dpsOp.getNumDpsInits())) {
    return 0;
  }
  return reinterpret_cast<uint64_t>(
      dpsOp.getDpsInits()[index].getAsOpaquePointer());
}

} // extern "C"

namespace crest {

void registerInterfacesDpsBindings() {
  Sregister_symbol("mlir_interfaces_dps_get_num_dps_inits",
                   (void*)::mlir_interfaces_dps_get_num_dps_inits);
  Sregister_symbol("mlir_interfaces_dps_get_dps_init_value",
                   (void*)::mlir_interfaces_dps_get_dps_init_value);
}

} // namespace crest
