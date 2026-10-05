/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

#include "Core/Core.h"
#include "Dialect/Shape/Shape.h"
#include "Support/ArrayRef.h"
#include "Support/Logging.h"
#include "Transforms/DialectConversion.h"

namespace crest {

// Hook for downstream projects to register their own dialect-specific
// FFI without modifying CREST itself.
static void (*g_extra_bindings_fn)() = nullptr;

extern "C" void crest_register_extra_bindings(void (*fn)()) {
  g_extra_bindings_fn = fn;
}

void registerMlirForeignFunctions() {
  registerCoreBindings();
  registerDialectShapeBindings();
  registerTransformsDialectConversionBindings();
  registerLoggingBindings();
  registerArrayRefBindings();
  if (g_extra_bindings_fn) {
    g_extra_bindings_fn();
  }
}

} // namespace crest
