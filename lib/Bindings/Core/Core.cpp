/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Registration hub — delegates to IR/, Transforms/, and Core/ shims.

#include "../IR/Block.h"
#include "../IR/OpBuilder.h"
#include "../IR/OpResult.h"
#include "../IR/RewriterBase.h"
#include "../IR/Value.h"
#include "../Transforms/GreedyPatternRewriteDriver.h"
#include "Attribute.h"
#include "Builder.h"
#include "Conversion.h"
#include "Operation.h"
#include "Types.h"

namespace crest {

void registerCoreBindings() {
  // Canonical registrations (new C names)
  registerIRBlockBindings();
  registerIROpBuilderBindings();
  registerIROpResultBindings();
  registerIRRewriterBaseBindings();
  registerIRValueBindings();
  registerTransformsGreedyPatternRewriteDriverBindings();
  // Backward-compat shims (register old C names still used by
  // scheme/mlir/core/*.sls)
  registerAttributeBindings();
  registerBuilderBindings();
  registerConversionBindings();
  registerOperationBindings();
  registerTypeBindings();
}

} // namespace crest
