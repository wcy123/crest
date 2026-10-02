/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

#include "SchemeWrapper.h"

namespace crest {

// Forward declarations — implemented in focused sub-files.
void registerConversionBindings();
void registerCoreBindings();
void registerShapeBindings();
void registerTensorBindings();
void registerLoggingBindings();

// Hook for downstream projects to register their own dialect-specific
// FFI without modifying CREST itself.
static void (*g_extra_bindings_fn)() = nullptr;

extern "C" void crest_register_extra_bindings(void (*fn)()) {
  g_extra_bindings_fn = fn;
}

void registerMlirForeignFunctions() {
  registerConversionBindings();
  registerCoreBindings();
  registerShapeBindings();
  registerTensorBindings();
  registerLoggingBindings();
  if (g_extra_bindings_fn) {
    g_extra_bindings_fn();
  }
  LLVM_DEBUG(llvm::dbgs() << "CREST: all MLIR FFI functions registered\n");
}

} // namespace crest
