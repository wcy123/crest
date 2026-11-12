/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/Dialect/SCF/IR/SCFDialect.h

#include "SCFDialect.h"
#include "../../../Support/Result.h"
#include "../../../Support/SchemeWrapper.h"
#include "mlir/Dialect/SCF/IR/SCF.h"
#include "mlir/IR/DialectRegistry.h"

namespace crest {

void registerDialectSCFIRSCFDialectBindings() {
  // Register SCFDialect into a DialectRegistry.
  // (registry-ptr) → void
  register_binding(
      "mlir::DialectRegistry::insert<mlir::scf::SCFDialect>",
      [](uint64_t registry_ptr) -> llvm::Error {
        CREST_TRY(crest_lookup1,
                  crest::CrestBox<mlir::DialectRegistry>::tryInner(
                      registry_ptr,
                      "mlir::DialectRegistry::insert<mlir::scf::SCFDialect>"));

        crest_lookup1.insert<mlir::scf::SCFDialect>();
        return llvm::Error::success();
      });
}

} // namespace crest
