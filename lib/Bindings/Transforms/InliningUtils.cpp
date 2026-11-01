/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/Transforms/InliningUtils.h

#include "InliningUtils.h"
#include "../../Crest/Dialect.h"
#include "../../Crest/InlinerInterface.h"
#include "mlir/Transforms/Passes.h"

namespace crest {

CrestPassHolder::CrestPassHolder(std::unique_ptr<mlir::Pass> p)
    : pass(std::move(p)) {}

void registerTransformsInliningUtilsBindings() {
  Sregister_symbol(
      "mlir::DialectInlinerInterface",
      (void*)+[](uint64_t dialect_ptr, ptr dispatcher) -> void {
        crest::LockedSchemeObject locked(dispatcher);

        auto get = [&](const char* name) -> crest::LockedSchemeObject {
          return crest::LockedSchemeObject(
              scheme_call(locked.get(), Sstring_to_symbol(name)));
        };

        auto isLegalCall = get("isLegalToInline/call");
        auto isLegalRegion = get("isLegalToInline/region");
        auto isLegalOp = get("isLegalToInline/op");

        if (isLegalCall.get() == Sfalse) {
          scheme_error("mlir::DialectInlinerInterface",
                       "isLegalToInline/call is required but not provided");
        }
        if (isLegalRegion.get() == Sfalse) {
          scheme_error("mlir::DialectInlinerInterface",
                       "isLegalToInline/region is required but not provided");
        }
        if (isLegalOp.get() == Sfalse) {
          scheme_error("mlir::DialectInlinerInterface",
                       "isLegalToInline/op is required but not provided");
        }

        auto* dialect = reinterpret_cast<crest::CrestDialect*>(dialect_ptr);
        auto iface = std::make_unique<CrestInlinerInterface>(dialect);
        iface->isLegalToInlineCallFn = std::move(isLegalCall);
        iface->isLegalToInlineRegionFn = std::move(isLegalRegion);
        iface->isLegalToInlineOpFn = std::move(isLegalOp);
        iface->handleTerminatorValueFn = get("handleTerminator/value");
        iface->handleTerminatorBlockFn = get("handleTerminator/block");
        iface->materializeCallConversionFn = get("materializeCallConversion");
        dialect->addInterface(std::move(iface));
      });

  Sregister_symbol(
      "mlir::createInlinerPass", (void*)+[]() -> uint64_t {
        return reinterpret_cast<uint64_t>(
            new CrestPassHolder(mlir::createInlinerPass()));
      });
}

} // namespace crest
