/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/Dialect/Affine/Transforms/Passes.h

#include "Passes.h"
#include "../../../Support/CrestObject.h"
#include "../../../Support/SchemeWrapper.h"
#include "mlir/Dialect/Affine/Transforms/Passes.h"

namespace crest {

void registerDialectAffineTransformsPassesBindings() {
  // LEAK WARNING: a raw mlir::Pass*. Nothing owns it until
  // mlir::PassManager::addPass or mlir::OpPassManager::addPass takes it
  // (lib/Bindings/Pass/PassManager.cpp): a pass that is made and never added
  // leaks.
  Sregister_symbol(
      "mlir::affine::createLoopFusionPass", (void*)+[]() -> uint64_t {
        return reinterpret_cast<uint64_t>(
            mlir::affine::createLoopFusionPass().release());
      });

  // LEAK WARNING: a raw mlir::Pass*. Nothing owns it until
  // mlir::PassManager::addPass or mlir::OpPassManager::addPass takes it
  // (lib/Bindings/Pass/PassManager.cpp): a pass that is made and never added
  // leaks.
  Sregister_symbol(
      "mlir::affine::createAffineScalarReplacementPass",
      (void*)+[]() -> uint64_t {
        return reinterpret_cast<uint64_t>(
            mlir::affine::createAffineScalarReplacementPass().release());
      });
}

} // namespace crest
