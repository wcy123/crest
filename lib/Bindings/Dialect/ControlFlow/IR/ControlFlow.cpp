/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/Dialect/ControlFlow/IR/ControlFlow.h

#include "ControlFlow.h"
#include "../../../Support/Result.h"
#include "../../../Support/SchemeWrapper.h"
#include "mlir/Dialect/ControlFlow/IR/ControlFlow.h"
#include "mlir/IR/DialectRegistry.h"

namespace crest {

void registerDialectControlFlowIRControlFlowBindings() {
  // Register ControlFlowDialect into a DialectRegistry.
  // (registry-ptr) → void
  register_binding(
      "mlir::DialectRegistry::insert<mlir::cf::ControlFlowDialect>",
      [](uint64_t registry_ptr) -> llvm::Error {
        CREST_TRY(
            crest_lookup1,
            crest::CrestBox<mlir::DialectRegistry>::tryInner(
                registry_ptr,
                "mlir::DialectRegistry::insert<mlir::cf::ControlFlowDialect>"));

        crest_lookup1.insert<mlir::cf::ControlFlowDialect>();
        return llvm::Error::success();
      });
}

} // namespace crest
