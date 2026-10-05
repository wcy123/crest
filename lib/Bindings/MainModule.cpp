/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Registration hub — calls every canonical register*Bindings() directly.
// No Core/ shim layer; each header belongs to its canonical IR/, Transforms/,
// Dialect/, or Interfaces/ sub-tree.

#include "Dialect/Shape/Shape.h"
#include "IR/Block.h"
#include "IR/BuiltinAttributes.h"
#include "IR/BuiltinTypes.h"
#include "IR/OpBuilder.h"
#include "IR/OpResult.h"
#include "IR/Operation.h"
#include "IR/OperationState.h"
#include "IR/RewriterBase.h"
#include "IR/Type.h"
#include "IR/Value.h"
#include "Interfaces/DestinationStyleOp.h"
#include "Support/ArrayRef.h"
#include "Support/Logging.h"
#include "Transforms/DialectConversion.h"
#include "Transforms/GreedyPatternRewriteDriver.h"

namespace crest {

// Hook for downstream projects to register their own dialect-specific
// FFI without modifying CREST itself.
static void (*g_extra_bindings_fn)() = nullptr;

extern "C" void crest_register_extra_bindings(void (*fn)()) {
  g_extra_bindings_fn = fn;
}

void registerMlirForeignFunctions() {
  registerDialectShapeBindings();
  registerInterfacesDpsBindings();
  registerIRBlockBindings();
  registerIRBuiltinAttributesBindings();
  registerIRBuiltinTypesBindings();
  registerIROpBuilderBindings();
  registerIROperationBindings();
  registerIROperationStateBindings();
  registerIROpResultBindings();
  registerIRRewriterBaseBindings();
  registerIRTypeBindings();
  registerIRValueBindings();
  registerArrayRefBindings();
  registerLoggingBindings();
  registerTransformsDialectConversionBindings();
  registerTransformsGreedyPatternRewriteDriverBindings();
  if (g_extra_bindings_fn) {
    g_extra_bindings_fn();
  }
}

} // namespace crest
