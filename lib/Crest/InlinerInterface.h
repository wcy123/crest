/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */
#pragma once
#include "../Bindings/Support/ArrayRef.h"
#include "../Bindings/Support/LockedSchemeObject.h"
#include "mlir/IR/IRMapping.h"
#include "mlir/Transforms/InliningUtils.h"

namespace crest {

// CrestInlinerInterface — Scheme-backed mlir::DialectInlinerInterface.
//
// Registered on a CrestDialect when the Scheme dialect calls
// (mlir::DialectInlinerInterface dialect dispatcher).  Each virtual method
// dispatches to the corresponding Scheme callback obtained from `dispatcher`.
struct CrestInlinerInterface : public mlir::DialectInlinerInterface {
  using mlir::DialectInlinerInterface::DialectInlinerInterface;

  LockedSchemeObject isLegalToInlineCallFn;
  LockedSchemeObject isLegalToInlineRegionFn;
  LockedSchemeObject isLegalToInlineOpFn;
  LockedSchemeObject handleTerminatorValueFn;
  LockedSchemeObject handleTerminatorBlockFn;
  LockedSchemeObject materializeCallConversionFn;

  bool isLegalToInline(mlir::Operation* call, mlir::Operation* callable,
                       bool wouldBeCloned) const final;

  bool isLegalToInline(mlir::Region* dest, mlir::Region* src,
                       bool wouldBeCloned, mlir::IRMapping&) const final;

  bool isLegalToInline(mlir::Operation* op, mlir::Region* dest,
                       bool wouldBeCloned, mlir::IRMapping&) const final;

  // Exit-block terminator: redirect dangling call results to return operands.
  void handleTerminator(mlir::Operation* op,
                        mlir::ValueRange valuesToRepl) const final;

  // Internal-block terminator: redirect branch target to newDest.
  void handleTerminator(mlir::Operation* op, mlir::Block* newDest) const final;

  mlir::Operation* materializeCallConversion(mlir::OpBuilder& builder,
                                             mlir::Value input,
                                             mlir::Type resultType,
                                             mlir::Location loc) const final;
};

void registerCrestInlinerInterfaceBindings();

} // namespace crest
