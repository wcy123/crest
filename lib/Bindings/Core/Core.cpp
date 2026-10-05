/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Registration hub — delegates to focused sub-files in Core/, IR/, Transforms/.

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
  registerAttributeBindings();
  registerBuilderBindings();
  registerConversionBindings();
  registerIRBlockBindings();
  registerIROpBuilderBindings();
  registerIROpResultBindings();
  registerIRRewriterBaseBindings();
  registerIRValueBindings();
  registerOperationBindings();
  registerTransformsGreedyPatternRewriteDriverBindings();
  registerTypeBindings();
}

} // namespace crest
