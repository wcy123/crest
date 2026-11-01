/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

#include "InlinerInterface.h"
#include "../Bindings/Support/SchemeWrapper.h"
#include "Dialect.h"
#include "mlir/IR/Builders.h"

namespace crest {

bool CrestInlinerInterface::isLegalToInline(mlir::Operation* call,
                                            mlir::Operation* callable,
                                            bool wouldBeCloned) const {
  ptr result = scheme_call(isLegalToInlineCallFn.get(),
                           Sunsigned64(reinterpret_cast<uint64_t>(call)),
                           Sunsigned64(reinterpret_cast<uint64_t>(callable)),
                           wouldBeCloned ? Strue : Sfalse);
  return result != Sfalse;
}

bool CrestInlinerInterface::isLegalToInline(mlir::Region* dest,
                                            mlir::Region* src,
                                            bool wouldBeCloned,
                                            mlir::IRMapping&) const {
  ptr result = scheme_call(isLegalToInlineRegionFn.get(),
                           Sunsigned64(reinterpret_cast<uint64_t>(dest)),
                           Sunsigned64(reinterpret_cast<uint64_t>(src)),
                           wouldBeCloned ? Strue : Sfalse);
  return result != Sfalse;
}

bool CrestInlinerInterface::isLegalToInline(mlir::Operation* op,
                                            mlir::Region* dest,
                                            bool wouldBeCloned,
                                            mlir::IRMapping&) const {
  ptr result = scheme_call(isLegalToInlineOpFn.get(),
                           Sunsigned64(reinterpret_cast<uint64_t>(op)),
                           Sunsigned64(reinterpret_cast<uint64_t>(dest)),
                           wouldBeCloned ? Strue : Sfalse);
  return result != Sfalse;
}

void CrestInlinerInterface::handleTerminator(
    mlir::Operation* op, mlir::ValueRange valuesToRepl) const {
  if (handleTerminatorValueFn.get() == Sfalse) {
    return;
  }
  // Pack the ValueRange into a heap-allocated CArrayRef<uintptr_t>.
  // The Scheme callback reads it via ArrayRef::size / ArrayRef::at;
  // it does not own or delete the object.
  std::vector<uintptr_t> ptrs;
  ptrs.reserve(valuesToRepl.size());
  for (auto v : valuesToRepl) {
    ptrs.push_back(reinterpret_cast<uintptr_t>(v.getAsOpaquePointer()));
  }
  auto* arr = new CArrayRef<uintptr_t>(ptrs.data(), ptrs.size());
  scheme_call(handleTerminatorValueFn.get(),
              Sunsigned64(reinterpret_cast<uint64_t>(op)),
              Sunsigned64(reinterpret_cast<uint64_t>(arr)));
  delete arr;
}

void CrestInlinerInterface::handleTerminator(mlir::Operation* op,
                                             mlir::Block* newDest) const {
  if (handleTerminatorBlockFn.get() == Sfalse) {
    return;
  }
  scheme_call(handleTerminatorBlockFn.get(),
              Sunsigned64(reinterpret_cast<uint64_t>(op)),
              Sunsigned64(reinterpret_cast<uint64_t>(newDest)));
}

mlir::Operation* CrestInlinerInterface::materializeCallConversion(
    mlir::OpBuilder& builder, mlir::Value input, mlir::Type resultType,
    mlir::Location loc) const {
  if (materializeCallConversionFn.get() == Sfalse) {
    return nullptr;
  }
  auto builderShell =
      std::make_unique<crest::CrestOwned<mlir::OpBuilder>>(builder);
  ptr result = scheme_call(
      materializeCallConversionFn.get(),
      Sunsigned64(reinterpret_cast<uint64_t>(builderShell.get())),
      Sunsigned64(reinterpret_cast<uint64_t>(input.getAsOpaquePointer())),
      Sunsigned64(reinterpret_cast<uint64_t>(resultType.getAsOpaquePointer())),
      Sunsigned64(reinterpret_cast<uint64_t>(loc.getAsOpaquePointer())));
  builder = builderShell->inner;
  if (result == Sfalse || !Sunsigned64_value(result)) {
    return nullptr;
  }
  return reinterpret_cast<mlir::Operation*>(Sunsigned64_value(result));
}

void registerCrestInlinerInterfaceBindings() {
  Sregister_symbol(
      "mlir::DialectInlinerInterface",
      (void*)+[](uint64_t dialect_ptr, ptr dispatch_fn) -> void {
        crest::LockedSchemeObject locked(dispatch_fn);

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

        auto* dialect = reinterpret_cast<CrestDialect*>(dialect_ptr);
        auto iface = std::make_unique<CrestInlinerInterface>(dialect);
        iface->isLegalToInlineCallFn = std::move(isLegalCall);
        iface->isLegalToInlineRegionFn = std::move(isLegalRegion);
        iface->isLegalToInlineOpFn = std::move(isLegalOp);
        iface->handleTerminatorValueFn = get("handleTerminator/value");
        iface->handleTerminatorBlockFn = get("handleTerminator/block");
        iface->materializeCallConversionFn = get("materializeCallConversion");
        dialect->addInterface(std::move(iface));
      });
}

} // namespace crest
