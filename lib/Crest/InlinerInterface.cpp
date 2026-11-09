/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

#include "InlinerInterface.h"
#include "../Bindings/Support/CrestObject.h"
#include "../Bindings/Support/SchemeWrapper.h"
#include "Dialect.h"
#include "mlir/IR/Builders.h"

namespace crest {

bool CrestInlinerInterface::isLegalToInline(mlir::Operation* call,
                                            mlir::Operation* callable,
                                            bool wouldBeCloned) const {
  CREST_REFRESH();
  return isLegalToInlineCallFn(reinterpret_cast<uint64_t>(call),
                               reinterpret_cast<uint64_t>(callable),
                               wouldBeCloned) != 0;
}

bool CrestInlinerInterface::isLegalToInline(mlir::Region* dest,
                                            mlir::Region* src,
                                            bool wouldBeCloned,
                                            mlir::IRMapping&) const {
  CREST_REFRESH();
  return isLegalToInlineRegionFn(reinterpret_cast<uint64_t>(dest),
                                 reinterpret_cast<uint64_t>(src),
                                 wouldBeCloned) != 0;
}

bool CrestInlinerInterface::isLegalToInline(mlir::Operation* op,
                                            mlir::Region* dest,
                                            bool wouldBeCloned,
                                            mlir::IRMapping&) const {
  CREST_REFRESH();
  return isLegalToInlineOpFn(reinterpret_cast<uint64_t>(op),
                             reinterpret_cast<uint64_t>(dest),
                             wouldBeCloned) != 0;
}

void CrestInlinerInterface::handleTerminator(
    mlir::Operation* op, mlir::ValueRange valuesToRepl) const {
  if (!handleTerminatorValueFn) {
    return;
  }
  // Pack the ValueRange into a CArrayRef<uintptr_t>, which Scheme reads during
  // the call.
  std::vector<uintptr_t> ptrs;
  ptrs.reserve(valuesToRepl.size());
  for (auto v : valuesToRepl) {
    ptrs.push_back(reinterpret_cast<uintptr_t>(v.getAsOpaquePointer()));
  }
  CArrayRef<uintptr_t> arr(ptrs.data(), ptrs.size());
  CREST_REFRESH();
  handleTerminatorValueFn(reinterpret_cast<uint64_t>(op),
                          reinterpret_cast<uint64_t>(&arr));
}

void CrestInlinerInterface::handleTerminator(mlir::Operation* op,
                                             mlir::Block* newDest) const {
  if (!handleTerminatorBlockFn) {
    return;
  }
  CREST_REFRESH();
  handleTerminatorBlockFn(reinterpret_cast<uint64_t>(op),
                          reinterpret_cast<uint64_t>(newDest));
}

mlir::Operation* CrestInlinerInterface::materializeCallConversion(
    mlir::OpBuilder& builder, mlir::Value input, mlir::Type resultType,
    mlir::Location loc) const {
  if (!materializeCallConversionFn) {
    return nullptr;
  }
  // Scheme sees the builder as a borrowed shell that lives for this call.
  crest::CrestBox<mlir::OpBuilder*> builder_shell(&builder);
  CREST_REFRESH();
  return reinterpret_cast<mlir::Operation*>(materializeCallConversionFn(
      reinterpret_cast<uint64_t>(&builder_shell),
      reinterpret_cast<uint64_t>(input.getAsOpaquePointer()),
      reinterpret_cast<uint64_t>(resultType.getAsOpaquePointer()),
      reinterpret_cast<uint64_t>(loc.getAsOpaquePointer())));
}

void registerCrestInlinerInterfaceBindings() {
  // mlir::DialectInlinerInterface (uptr dialect) (uptr isLegalToInline/call)
  //   (uptr isLegalToInline/region) (uptr isLegalToInline/op)
  //   (uptr handleTerminator/value) (uptr handleTerminator/block)
  //   (uptr materializeCallConversion)
  //
  // Each uptr is the entry point of a foreign-callable made in Scheme, or 0 for
  // an optional method the dialect does not have.
  Sregister_symbol(
      "mlir::DialectInlinerInterface",
      (void*)+[](uint64_t dialect_ptr, uint64_t isLegalCall,
                 uint64_t isLegalRegion, uint64_t isLegalOp,
                 uint64_t handleTerminatorValue, uint64_t handleTerminatorBlock,
                 uint64_t materializeCallConversion) -> void {
        auto* dialect = reinterpret_cast<CrestDialect*>(dialect_ptr);
        auto iface = std::make_unique<CrestInlinerInterface>(dialect);
        iface->isLegalToInlineCallFn =
            reinterpret_cast<decltype(iface->isLegalToInlineCallFn)>(
                isLegalCall);
        iface->isLegalToInlineRegionFn =
            reinterpret_cast<decltype(iface->isLegalToInlineRegionFn)>(
                isLegalRegion);
        iface->isLegalToInlineOpFn =
            reinterpret_cast<decltype(iface->isLegalToInlineOpFn)>(isLegalOp);
        iface->handleTerminatorValueFn =
            reinterpret_cast<decltype(iface->handleTerminatorValueFn)>(
                handleTerminatorValue);
        iface->handleTerminatorBlockFn =
            reinterpret_cast<decltype(iface->handleTerminatorBlockFn)>(
                handleTerminatorBlock);
        iface->materializeCallConversionFn =
            reinterpret_cast<decltype(iface->materializeCallConversionFn)>(
                materializeCallConversion);
        dialect->addInterface(std::move(iface));
      });
}

} // namespace crest
