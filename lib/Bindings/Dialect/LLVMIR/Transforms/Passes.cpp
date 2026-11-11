/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/Dialect/LLVMIR/Transforms/Passes.h

#include "Passes.h"
#include "../../../Support/CrestObject.h"
#include "../../../Support/SchemeWrapper.h"
#include "../../../Transforms/Passes.h"
#include "mlir/Dialect/LLVMIR/Transforms/Passes.h"

namespace crest {

void registerDialectLLVMIRTransformsPassesBindings() {
  // mlir::LLVM::createDIScopeForLLVMFuncOpPass
  // () → mlir::Pass* uptr, owned by the pass manager that it is added to
  Sregister_symbol(
      "mlir::LLVM::createDIScopeForLLVMFuncOpPass", (void*)+[]() -> uint64_t {
        return reinterpret_cast<uint64_t>(
            mlir::LLVM::createDIScopeForLLVMFuncOpPass().release());
      });
}

} // namespace crest
