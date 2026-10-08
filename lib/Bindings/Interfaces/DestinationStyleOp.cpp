/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/Interfaces/DestinationStyleOpInterface.h

#include "DestinationStyleOp.h"
#include "../Support/SchemeWrapper.h"
#include "mlir/IR/Operation.h"
#include "mlir/Interfaces/DestinationStyleOpInterface.h"

namespace crest {

void registerInterfacesDpsBindings() {
  Sregister_symbol(
      "mlir::DestinationStyleOpInterface::getNumDpsInits",
      (void*)+[](uint64_t op_ptr) -> int {
        if (!op_ptr) {
          scheme_error("mlir::DestinationStyleOpInterface::getNumDpsInits",
                       "op must not be null");
        }
        mlir::Operation* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        auto dpsOp = mlir::dyn_cast<mlir::DestinationStyleOpInterface>(op);
        if (!dpsOp) {
          return 0;
        }
        return static_cast<int>(dpsOp.getNumDpsInits());
      });
  Sregister_symbol(
      "mlir::DestinationStyleOpInterface::getDpsInitOperand",
      (void*)+[](uint64_t op_ptr, int index) -> uint64_t {
        if (!op_ptr) {
          scheme_error("mlir::DestinationStyleOpInterface::getDpsInitOperand",
                       "op must not be null");
        }
        mlir::Operation* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        auto dpsOp = mlir::dyn_cast<mlir::DestinationStyleOpInterface>(op);
        if (!dpsOp) {
          scheme_error("mlir::DestinationStyleOpInterface::getDpsInitOperand",
                       "op does not implement DestinationStyleOpInterface");
        }
        if (index < 0 || index >= static_cast<int>(dpsOp.getNumDpsInits())) {
          scheme_error("mlir::DestinationStyleOpInterface::getDpsInitOperand",
                       "index out of range");
        }
        return reinterpret_cast<uint64_t>(
            dpsOp.getDpsInits()[index].getAsOpaquePointer());
      });
}

} // namespace crest
