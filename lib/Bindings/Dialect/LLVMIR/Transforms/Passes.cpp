/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/Dialect/LLVMIR/Transforms/Passes.h

#include "Passes.h"
#include "../../../Support/CrestObject.h"
#include "../../../Support/Result.h"
#include "../../../Support/SchemeWrapper.h"
#include "../../../Transforms/Passes.h"
#include "mlir/Dialect/LLVMIR/Transforms/Passes.h"

namespace crest {

void registerDialectLLVMIRTransformsPassesBindings() {
  // mlir::LLVM::createDIScopeForLLVMFuncOpPass
  // () → mlir::Pass* uptr, owned by the pass manager that it is added to
  // LEAK WARNING: a raw mlir::Pass*. Nothing owns it until
  // mlir::PassManager::addPass or mlir::OpPassManager::addPass takes it
  // (lib/Bindings/Pass/PassManager.cpp): a pass that is made and never added
  // leaks.
  register_binding(
      "mlir::LLVM::createDIScopeForLLVMFuncOpPass", []() -> uint64_t {
        return reinterpret_cast<uint64_t>(
            mlir::LLVM::createDIScopeForLLVMFuncOpPass().release());
      });
}

} // namespace crest
