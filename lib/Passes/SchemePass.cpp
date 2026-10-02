/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */
//===- SchemePass.cpp - Generic pass runner for Scheme-defined passes -----===//
//
// Loads a Scheme library by name and calls its run-pass function.
// The module name is specified via the 'module' option using slash-separated
// R6RS library name notation (e.g. "passes/my-rewrite").
//
//===----------------------------------------------------------------------===//

#include "Passes.h"
#include "../Interpreter/ChezSchemeInterpreter.h"
#include "mlir/Dialect/Func/IR/FuncOps.h"
#include "mlir/Dialect/Shape/IR/Shape.h"
#include "mlir/IR/BuiltinOps.h"

#include <algorithm>

namespace crest {

#define GEN_PASS_DEF_SCHEMEPASS
#include "Passes.h.inc"

namespace {

struct SchemePass : impl::SchemePassBase<SchemePass> {
  using impl::SchemePassBase<SchemePass>::SchemePassBase;

  void getDependentDialects(mlir::DialectRegistry &registry) const override {
    registry.insert<mlir::func::FuncDialect,
                    mlir::shape::ShapeDialect>();
  }

  void runOnOperation() override {
    if (moduleName.empty()) {
      emitError(getOperation().getLoc(),
                "Scheme module name not specified. "
                "Use --scheme-pass=\"module=<name>\"");
      signalPassFailure();
      return;
    }

    if (!ChezSchemeInterpreter::isInitialized()) {
      SchemeLogLevel level = ChezSchemeInterpreter::parseLogLevel(logLevel);
      ChezSchemeInterpreter::initialize(level);
    }
    ChezSchemeInterpreter::setLogLevel(
        ChezSchemeInterpreter::parseLogLevel(logLevel));

    // Convert slash-separated name to space-separated R6RS library name.
    // e.g. "passes/my-rewrite" → "(import (passes my-rewrite))"
    std::string libraryName = moduleName;
    std::replace(libraryName.begin(), libraryName.end(), '/', ' ');
    std::string importCode = "(import (" + libraryName + "))";

    if (!ChezSchemeInterpreter::eval(importCode.c_str())) {
      emitError(getOperation().getLoc(), "Failed to import (")
          << moduleName << ")";
      signalPassFailure();
      return;
    }

    ChezSchemeInterpreter::callPassFunction("run-pass", getOperation());
  }
};

} // namespace
} // namespace crest
