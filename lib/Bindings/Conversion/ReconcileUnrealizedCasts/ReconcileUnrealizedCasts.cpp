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
  // LEAK WARNING: a raw mlir::Pass*. Nothing owns it until
  // mlir::PassManager::addPass or mlir::OpPassManager::addPass takes it
  // (lib/Bindings/Pass/PassManager.cpp): a pass that is made and never added
  // leaks.
  Sregister_symbol(
      "mlir::createReconcileUnrealizedCastsPass", (void*)+[]() -> uint64_t {
        return reinterpret_cast<uint64_t>(
            mlir::createReconcileUnrealizedCastsPass().release());
      });
}

} // namespace crest
