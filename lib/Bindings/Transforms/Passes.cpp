/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/Transforms/Passes.h

#include "Passes.h"
#include "../Support/CrestObject.h"
#include "../Support/Result.h"
#include "../Support/SchemeWrapper.h"
#include "mlir/Transforms/Passes.h"

namespace crest {

void registerTransformsPassesBindings() {
  // LEAK WARNING: a raw mlir::Pass*. Nothing owns it until
  // mlir::PassManager::addPass or mlir::OpPassManager::addPass takes it
  // (lib/Bindings/Pass/PassManager.cpp): a pass that is made and never added
  // leaks.
  Sregister_symbol(
      "mlir::createCanonicalizerPass", (void*)+[]() -> ptr {
        return Sunsigned64(reinterpret_cast<uint64_t>(
            mlir::createCanonicalizerPass().release()));
      });

  // LEAK WARNING: a raw mlir::Pass*. Nothing owns it until
  // mlir::PassManager::addPass or mlir::OpPassManager::addPass takes it
  // (lib/Bindings/Pass/PassManager.cpp): a pass that is made and never added
  // leaks.
  Sregister_symbol(
      "mlir::createCSEPass", (void*)+[]() -> ptr {
        return Sunsigned64(
            reinterpret_cast<uint64_t>(mlir::createCSEPass().release()));
      });
}

} // namespace crest
