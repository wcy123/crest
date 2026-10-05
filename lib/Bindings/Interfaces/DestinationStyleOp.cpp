/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/Interfaces/DestinationStyleOpInterface.h

#include "DestinationStyleOp.h"
#include "../Support/SchemeWrapper.h"
#include "mlir/IR/Operation.h"
#include "mlir/Interfaces/DestinationStyleOpInterface.h"

static void scheme_error(const char* who, const char* msg) {
  Scall2(Stop_level_value(Sstring_to_symbol("error")), Sstring(who),
         Sstring(msg));
}

extern "C" {

int mlir_interfaces_dps_get_num_dps_inits(uint64_t op_ptr) {
  if (!op_ptr) {
    scheme_error("mlir-interfaces-dps-get-num-dps-inits",
                 "op must not be null");
    return 0; // unreachable — error performs non-local exit
  }
  mlir::Operation* op = reinterpret_cast<mlir::Operation*>(op_ptr);
  auto dpsOp = mlir::dyn_cast<mlir::DestinationStyleOpInterface>(op);
  if (!dpsOp) {
    scheme_error("mlir-interfaces-dps-get-num-dps-inits",
                 "op does not implement DestinationStyleOpInterface");
    return 0; // unreachable — error performs non-local exit
  }
  return static_cast<int>(dpsOp.getNumDpsInits());
}

uint64_t mlir_interfaces_dps_get_dps_init_value(uint64_t op_ptr, int index) {
  if (!op_ptr) {
    scheme_error("mlir-interfaces-dps-get-dps-init-value",
                 "op must not be null");
    return 0; // unreachable — error performs non-local exit
  }
  mlir::Operation* op = reinterpret_cast<mlir::Operation*>(op_ptr);
  auto dpsOp = mlir::dyn_cast<mlir::DestinationStyleOpInterface>(op);
  if (!dpsOp) {
    scheme_error("mlir-interfaces-dps-get-dps-init-value",
                 "op does not implement DestinationStyleOpInterface");
    return 0; // unreachable — error performs non-local exit
  }
  if (index < 0 || index >= static_cast<int>(dpsOp.getNumDpsInits())) {
    scheme_error("mlir-interfaces-dps-get-dps-init-value",
                 "index out of range");
    return 0; // unreachable — error performs non-local exit
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
