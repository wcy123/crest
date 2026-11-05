/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/Dialect/ControlFlow/IR/ControlFlow.h

#include "ControlFlow.h"
#include "../../../Support/SchemeWrapper.h"
#include "mlir/Dialect/ControlFlow/IR/ControlFlow.h"
#include "mlir/IR/DialectRegistry.h"

namespace crest {

void registerDialectControlFlowIRControlFlowBindings() {
  // Register ControlFlowDialect into a DialectRegistry.
  // (registry-ptr) → void
  Sregister_symbol(
      "mlir::cf::ControlFlowDialect",
      (void*)+[](uint64_t registry_ptr) -> void {
        crest::CrestBox<mlir::DialectRegistry>::inner(
            registry_ptr, "mlir::cf::ControlFlowDialect")
            .insert<mlir::cf::ControlFlowDialect>();
      });
}

} // namespace crest
