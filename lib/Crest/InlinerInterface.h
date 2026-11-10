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
// Added to a CrestDialect by its :interfaces clause (the dialect-level one),
// through attachDialectInlinerInterface.  Each virtual method
// calls the entry point of a Scheme foreign-callable made once for the
// dialect's library (see scheme/crest/callback.sls); the optional ones may be
// nullptr.
struct CrestInlinerInterface : public mlir::DialectInlinerInterface {
  using mlir::DialectInlinerInterface::DialectInlinerInterface;

  int (*isLegalToInlineCallFn)(uint64_t call, uint64_t callable,
                               int wouldBeCloned) = nullptr;
  int (*isLegalToInlineRegionFn)(uint64_t dest, uint64_t src,
                                 int wouldBeCloned) = nullptr;
  int (*isLegalToInlineOpFn)(uint64_t op, uint64_t dest,
                             int wouldBeCloned) = nullptr;
  void (*handleTerminatorValueFn)(uint64_t op, uint64_t values) = nullptr;
  void (*handleTerminatorBlockFn)(uint64_t op, uint64_t newDest) = nullptr;
  uint64_t (*materializeCallConversionFn)(uint64_t builder, uint64_t input,
                                          uint64_t resultType,
                                          uint64_t loc) = nullptr;

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

class CrestDialect;

/// Give `dialect` its inliner interface from `dispatcher`, the Scheme procedure
/// that the interface's macro answers (see (mlir Transforms InliningUtils)):
/// from a method name to the entry point of a callable made once, when the
/// library of the dialect was loaded, or 0. The caller keeps it locked.
void attachDialectInlinerInterface(CrestDialect& dialect,
                                   const LockedSchemeObject& dispatcher);

} // namespace crest
