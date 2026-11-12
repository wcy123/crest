/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

#include "InlinerInterface.h"
#include "../Bindings/Support/CrestObject.h"
#include "../Bindings/Support/Result.h"
#include "../Bindings/Support/SchemeWrapper.h"
#include "Dialect.h"
#include "Interface.h"
#include "mlir/IR/Builders.h"

namespace crest {

bool CrestInlinerInterface::isLegalToInline(mlir::Operation* call,
                                            mlir::Operation* callable,
                                            bool wouldBeCloned) const {
  return isLegalToInlineCallFn(reinterpret_cast<uint64_t>(call),
                               reinterpret_cast<uint64_t>(callable),
                               static_cast<int>(wouldBeCloned)) != 0;
}

bool CrestInlinerInterface::isLegalToInline(mlir::Region* dest,
                                            mlir::Region* src,
                                            bool wouldBeCloned,
                                            mlir::IRMapping&) const {
  return isLegalToInlineRegionFn(reinterpret_cast<uint64_t>(dest),
                                 reinterpret_cast<uint64_t>(src),
                                 static_cast<int>(wouldBeCloned)) != 0;
}

bool CrestInlinerInterface::isLegalToInline(mlir::Operation* op,
                                            mlir::Region* dest,
                                            bool wouldBeCloned,
                                            mlir::IRMapping&) const {
  return isLegalToInlineOpFn(reinterpret_cast<uint64_t>(op),
                             reinterpret_cast<uint64_t>(dest),
                             static_cast<int>(wouldBeCloned)) != 0;
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
  handleTerminatorValueFn(reinterpret_cast<uint64_t>(op),
                          reinterpret_cast<uint64_t>(&arr));
}

void CrestInlinerInterface::handleTerminator(mlir::Operation* op,
                                             mlir::Block* newDest) const {
  if (!handleTerminatorBlockFn) {
    return;
  }
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
  uint64_t answer = materializeCallConversionFn(
      reinterpret_cast<uint64_t>(&builder_shell),
      reinterpret_cast<uint64_t>(input.getAsOpaquePointer()),
      reinterpret_cast<uint64_t>(resultType.getAsOpaquePointer()),
      reinterpret_cast<uint64_t>(loc.getAsOpaquePointer()));
  return reinterpret_cast<mlir::Operation*>(answer);
}

void attachDialectInlinerInterface(CrestDialect& dialect,
                                   const LockedSchemeObject& dispatcher) {
  auto iface = std::make_unique<CrestInlinerInterface>(&dialect);
  // Optional ones keep the default when the dialect has no clause: their
  // function stays null.
  installInterfaceEntry(iface->isLegalToInlineCallFn, dispatcher,
                        "isLegalToInline/call");
  installInterfaceEntry(iface->isLegalToInlineRegionFn, dispatcher,
                        "isLegalToInline/region");
  installInterfaceEntry(iface->isLegalToInlineOpFn, dispatcher,
                        "isLegalToInline/op");
  installInterfaceEntry(iface->handleTerminatorValueFn, dispatcher,
                        "handleTerminator/value");
  installInterfaceEntry(iface->handleTerminatorBlockFn, dispatcher,
                        "handleTerminator/block");
  installInterfaceEntry(iface->materializeCallConversionFn, dispatcher,
                        "materializeCallConversion");
  dialect.addInterface(std::move(iface));
}

} // namespace crest
