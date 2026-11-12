/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */
//===- crest-opt.cpp - CREST optimizer driver -----------------------------===//
//
// Analogous to mlir-opt. Registers all CREST passes and standard MLIR
// dialects, then delegates to MlirOptMain.
//
// --crest-scheme-dialect=name=module/path
//   Pre-registers a Scheme-defined dialect into the global DialectRegistry
//   before MlirOptMain creates any MLIRContext. The parser then lazy-loads
//   the dialect on first encounter of the dialect's ops, avoiding the
//   UnregisteredOpModel use-after-free that would occur if the dialect were
//   registered after parsing.
//
//===----------------------------------------------------------------------===//

#include "../lib/Bindings/Support/Result.h"
#include "../lib/Crest/Dialect.h"
#include "crest/Passes/Passes.h"
#include "mlir/Dialect/Affine/IR/AffineOps.h"
#include "mlir/Dialect/Arith/IR/Arith.h"
#include "mlir/Dialect/ControlFlow/IR/ControlFlow.h"
#include "mlir/Dialect/Func/IR/FuncOps.h"
#include "mlir/Dialect/LLVMIR/LLVMDialect.h"
#include "mlir/Dialect/MemRef/IR/MemRef.h"
#include "mlir/Dialect/SCF/IR/SCF.h"
#include "mlir/Dialect/Shape/IR/Shape.h"
#include "mlir/Dialect/Tensor/IR/Tensor.h"
#include "mlir/IR/DialectRegistry.h"
#include "mlir/Tools/mlir-opt/MlirOptMain.h"
#include "mlir/Transforms/Passes.h"

#include "llvm/Support/CommandLine.h"

static llvm::cl::list<std::string> SchemeDialects(
    "crest-scheme-dialect",
    llvm::cl::desc("Register a Scheme-defined dialect before parsing. "
                   "Format: --crest-scheme-dialect=name=module/path. "
                   "May be specified multiple times. "
                   "Use for dialects whose ops appear in the input MLIR file."),
    llvm::cl::ZeroOrMore);

int main(int argc, char** argv) {
  // MLIR drives, and loads a Scheme dialect while it parses: no Scheme program
  // is there to raise the error of a callback (see unansweredErrorStops).
  crest::unansweredErrorStops() = true;
  mlir::DialectRegistry registry;
  // The dialects the Scheme passes and the Toy tutorial create ops of, as toyc
  // registers them.
  registry.insert<mlir::affine::AffineDialect, mlir::arith::ArithDialect,
                  mlir::cf::ControlFlowDialect, mlir::func::FuncDialect,
                  mlir::LLVM::LLVMDialect, mlir::memref::MemRefDialect,
                  mlir::scf::SCFDialect, mlir::shape::ShapeDialect,
                  mlir::tensor::TensorDialect>();
  crest::registerCrestPass();
  mlir::registerTransformsPasses(); // --canonicalize, --cse, --inliner, etc.

  // Pre-scan argv for --crest-scheme-dialect= entries and populate the global
  // registry before MlirOptMain creates any MLIRContext. The cl::list above
  // ensures the option is accepted and visible in --help; we process it
  // manually here to guarantee registry population precedes context creation.
  for (int i = 1; i < argc; ++i) {
    llvm::StringRef arg(argv[i]);
    if (!arg.consume_front("--crest-scheme-dialect=")) {
      continue;
    }
    auto [dialect_name, module_name] = arg.split('=');
    if (dialect_name.empty() || module_name.empty()) {
      llvm::errs() << "crest-opt: --crest-scheme-dialect: expected "
                      "name=module/path, got '"
                   << arg << "'\n";
      continue;
    }
    // The dialect is created lazily, when the first of its ops is parsed, and
    // cannot fail then, so a library that does not load is reported here.
    if (auto error = crest::validateSchemeDialect(dialect_name.str(),
                                                  module_name.str())) {
      llvm::errs() << "error: Failed to import Scheme library: " << module_name
                   << ": " << *error << "\n";
      return 1;
    }
    auto [type_id, factory] =
        crest::dialectFactory(dialect_name.str(), module_name.str());
    registry.insert(type_id, dialect_name.str(), factory);
  }

  return mlir::asMainReturnCode(
      mlir::MlirOptMain(argc, argv, "CREST optimizer driver\n", registry));
}
