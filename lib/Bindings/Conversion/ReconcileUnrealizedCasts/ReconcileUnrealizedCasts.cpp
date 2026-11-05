/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/Conversion/ReconcileUnrealizedCasts/ReconcileUnrealizedCasts.h

#include "ReconcileUnrealizedCasts.h"
#include "../../Support/CrestObject.h"
#include "../../Support/SchemeWrapper.h"
#include "mlir/Conversion/ReconcileUnrealizedCasts/ReconcileUnrealizedCasts.h"
#include "mlir/Pass/Pass.h"

namespace crest {

void registerConversionReconcileUnrealizedCastsBindings() {
  Sregister_symbol(
      "mlir::createReconcileUnrealizedCastsPass", (void*)+[]() -> uint64_t {
        return reinterpret_cast<uint64_t>(
            new CrestBox<std::unique_ptr<mlir::Pass>>(
                mlir::createReconcileUnrealizedCastsPass()));
      });
}

} // namespace crest
