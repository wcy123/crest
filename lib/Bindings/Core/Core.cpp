/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Registration hub for all MLIR C API → Scheme bindings.

#include "../IR/Block.h"
#include "../IR/BuiltinAttributes.h"
#include "../IR/BuiltinTypes.h"
#include "../IR/OpBuilder.h"
#include "../IR/OpResult.h"
#include "../IR/Operation.h"
#include "../IR/RewriterBase.h"
#include "../IR/Type.h"
#include "../IR/Value.h"
#include "../Interfaces/DestinationStyleOp.h"
#include "../Transforms/DialectConversion.h"
#include "../Transforms/GreedyPatternRewriteDriver.h"
#include "Builder.h"

namespace crest {

void registerCoreBindings() {
  registerIRBuiltinAttributesBindings();
  registerBuilderBindings();
  registerTransformsDialectConversionBindings();
  registerIRBlockBindings();
  registerIROpBuilderBindings();
  registerIROpResultBindings();
  registerIROperationBindings();
  registerIRRewriterBaseBindings();
  registerInterfacesDpsBindings();
  registerTransformsGreedyPatternRewriteDriverBindings();
  registerIRBuiltinTypesBindings();
  registerIRTypeBindings();
  registerIRValueBindings();
}

} // namespace crest
