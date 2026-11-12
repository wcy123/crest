/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/Interfaces/DestinationStyleOpInterface.h

#include "DestinationStyleOpInterface.h"
#include "../Support/Result.h"
#include "../Support/SchemeWrapper.h"
#include "mlir/IR/Operation.h"
#include "mlir/Interfaces/DestinationStyleOpInterface.h"

namespace crest {

void registerInterfacesDpsBindings() {
  register_binding(
      "mlir::DestinationStyleOpInterface::getNumDpsInits",
      [](uint64_t op_ptr) -> llvm::Expected<int> {
        if (!op_ptr) {
          return fail("mlir::DestinationStyleOpInterface::getNumDpsInits",
                      llvm::Twine("op must not be null"));
        }
        mlir::Operation* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        auto dpsOp = mlir::dyn_cast<mlir::DestinationStyleOpInterface>(op);
        if (!dpsOp) {
          return 0;
        }
        return static_cast<int>(dpsOp.getNumDpsInits());
      });
  register_binding(
      "mlir::DestinationStyleOpInterface::getDpsInitOperand",
      [](uint64_t op_ptr, int index) -> llvm::Expected<uint64_t> {
        if (!op_ptr) {
          return fail("mlir::DestinationStyleOpInterface::getDpsInitOperand",
                      llvm::Twine("op must not be null"));
        }
        mlir::Operation* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        auto dpsOp = mlir::dyn_cast<mlir::DestinationStyleOpInterface>(op);
        if (!dpsOp) {
          return fail(
              "mlir::DestinationStyleOpInterface::getDpsInitOperand",
              llvm::Twine("op does not implement DestinationStyleOpInterface"));
        }
        if (index < 0 || index >= static_cast<int>(dpsOp.getNumDpsInits())) {
          return fail("mlir::DestinationStyleOpInterface::getDpsInitOperand",
                      llvm::Twine("index out of range"));
        }
        return reinterpret_cast<uint64_t>(
            dpsOp.getDpsInits()[static_cast<size_t>(index)]
                .getAsOpaquePointer());
      });
}

} // namespace crest
