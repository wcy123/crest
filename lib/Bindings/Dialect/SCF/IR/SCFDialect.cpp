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
  Sregister_symbol(
      "mlir::DialectRegistry::insert<mlir::scf::SCFDialect>",
      (void*)+[](uint64_t registry_ptr) -> ptr {
        auto* crest_lookup1_box =
            crest::CrestBox<mlir::DialectRegistry>::inner(registry_ptr);
        if (!crest_lookup1_box) {
          return scheme_error(
              "mlir::DialectRegistry::insert<mlir::scf::SCFDialect>",
              "null pointer or not a CrestBox<mlir::DialectRegistry>");
        }
        auto& crest_lookup1 = *crest_lookup1_box;

        crest_lookup1.insert<mlir::scf::SCFDialect>();
        return Svoid;
      });
}

} // namespace crest
