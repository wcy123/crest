/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/Transforms/InliningUtils.h

#include "InliningUtils.h"
#include "../../Crest/Dialect.h"
#include "../Support/LockedSchemeObject.h"
#include "../Support/SchemeWrapper.h"
#include "mlir/IR/Builders.h"
#include "mlir/Pass/Pass.h"
#include "mlir/Transforms/InliningUtils.h"
#include "mlir/Transforms/Passes.h"

namespace crest {

CrestPassHolder::CrestPassHolder(std::unique_ptr<mlir::Pass> p)
    : pass(std::move(p)) {}

} // namespace crest

namespace {

struct CrestInlinerInterface : public mlir::DialectInlinerInterface {
  using mlir::DialectInlinerInterface::DialectInlinerInterface;

  crest::LockedSchemeObject isLegalToInlineCallFn;
  crest::LockedSchemeObject isLegalToInlineRegionFn;
  crest::LockedSchemeObject isLegalToInlineOpFn;
  crest::LockedSchemeObject handleTerminatorFn;
  crest::LockedSchemeObject materializeCallConversionFn;

  bool isLegalToInline(mlir::Operation* call, mlir::Operation* callable,
                       bool wouldBeCloned) const final {
    ptr result = scheme_call(isLegalToInlineCallFn.get(),
                             Sunsigned64(reinterpret_cast<uint64_t>(call)),
                             Sunsigned64(reinterpret_cast<uint64_t>(callable)),
                             wouldBeCloned ? Strue : Sfalse);
    return result != Sfalse;
  }

  bool isLegalToInline(mlir::Region* dest, mlir::Region* src,
                       bool wouldBeCloned, mlir::IRMapping&) const final {
    ptr result = scheme_call(isLegalToInlineRegionFn.get(),
                             Sunsigned64(reinterpret_cast<uint64_t>(dest)),
                             Sunsigned64(reinterpret_cast<uint64_t>(src)),
                             wouldBeCloned ? Strue : Sfalse);
    return result != Sfalse;
  }

  bool isLegalToInline(mlir::Operation* op, mlir::Region* dest,
                       bool wouldBeCloned, mlir::IRMapping&) const final {
    ptr result = scheme_call(isLegalToInlineOpFn.get(),
                             Sunsigned64(reinterpret_cast<uint64_t>(op)),
                             Sunsigned64(reinterpret_cast<uint64_t>(dest)),
                             wouldBeCloned ? Strue : Sfalse);
    return result != Sfalse;
  }

  void handleTerminator(mlir::Operation* op,
                        mlir::ValueRange valuesToRepl) const final {
    if (handleTerminatorFn.get() == Sfalse) {
      return;
    }
    ptr repl_list = Snil;
    for (int i = static_cast<int>(valuesToRepl.size()) - 1; i >= 0; --i) {
      repl_list =
          Scons(Sunsigned64(reinterpret_cast<uint64_t>(
                    valuesToRepl[static_cast<size_t>(i)].getAsOpaquePointer())),
                repl_list);
    }
    scheme_call(
        handleTerminatorFn.get(), Sunsigned64(reinterpret_cast<uint64_t>(op)),
        Sunsigned64(static_cast<uint64_t>(valuesToRepl.size())), repl_list);
  }

  mlir::Operation* materializeCallConversion(mlir::OpBuilder& builder,
                                             mlir::Value input,
                                             mlir::Type resultType,
                                             mlir::Location loc) const final {
    if (materializeCallConversionFn.get() == Sfalse) {
      return nullptr;
    }
    auto builderShell =
        std::make_unique<crest::CrestOwned<mlir::OpBuilder>>(builder);
    ptr result = scheme_call(
        materializeCallConversionFn.get(),
        Sunsigned64(reinterpret_cast<uint64_t>(builderShell.get())),
        Sunsigned64(reinterpret_cast<uint64_t>(input.getAsOpaquePointer())),
        Sunsigned64(
            reinterpret_cast<uint64_t>(resultType.getAsOpaquePointer())),
        Sunsigned64(reinterpret_cast<uint64_t>(loc.getAsOpaquePointer())));
    builder = builderShell->inner;
    if (result == Sfalse || !Sunsigned64_value(result)) {
      return nullptr;
    }
    return reinterpret_cast<mlir::Operation*>(Sunsigned64_value(result));
  }
};

} // anonymous namespace

namespace crest {

void registerTransformsInliningUtilsBindings() {
  /// dialect_ptr: CrestDialect*, dispatcher: Scheme procedure (method → lambda
  /// | #f)
  Sregister_symbol(
      "mlir::DialectInlinerInterface",
      (void*)+[](uint64_t dialect_ptr, ptr dispatcher) -> void {
        crest::LockedSchemeObject locked(dispatcher);

        // Each scheme_call may trigger GC — lock every callback immediately.
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
        iface->handleTerminatorFn = get("handleTerminator");
        iface->materializeCallConversionFn = get("materializeCallConversion");
        dialect->addInterface(std::move(iface));
      });

  /// → CrestPassHolder* (consumed by mlir::PassManager::addPass)
  Sregister_symbol(
      "mlir::createInlinerPass", (void*)+[]() -> uint64_t {
        return reinterpret_cast<uint64_t>(
            new CrestPassHolder(mlir::createInlinerPass()));
      });
}

} // namespace crest
