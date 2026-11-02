/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/Dialect/SCF/IR/SCFDialect.h

#include "SCFDialect.h"
#include "../../../Support/SchemeWrapper.h"
#include "mlir/Dialect/SCF/IR/SCF.h"
#include "mlir/IR/DialectRegistry.h"

namespace crest {

void registerDialectSCFIRSCFDialectBindings() {
  // Register SCFDialect into a DialectRegistry.
  // (registry-ptr) → void
  Sregister_symbol(
      "mlir::scf::SCFDialect", (void*)+[](uint64_t registry_ptr) -> void {
        crest::as_ref<mlir::DialectRegistry>(registry_ptr,
                                             "mlir::scf::SCFDialect")
            .insert<mlir::scf::SCFDialect>();
      });
}

} // namespace crest
