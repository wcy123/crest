/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

#include "Conversion.h"
#include "Core.h"
#include "Dialects/HipSR.h"
#include "Dialects/Shape.h"
#include "Logging.h"
#include "Support/ArrayRef.h"

namespace crest {

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
  registerLoggingBindings();
  registerArrayRefBindings();
  registerHipSRDialectBindings();
  if (g_extra_bindings_fn) {
    g_extra_bindings_fn();
  }
}

} // namespace crest
