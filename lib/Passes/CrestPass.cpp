/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */
//===- CrestPass.cpp - CREST pass runner for Scheme-defined passes --------===//
//
// Registers --crest-pass via mlir::PassPipelineRegistration (no tablegen).
// The 'module' option names a Scheme library; 'log-level' controls verbosity.
//
//===----------------------------------------------------------------------===//

#include "../Interpreter/ChezSchemeInterpreter.h"
#include "crest/Passes/Passes.h"
#include "mlir/Dialect/Func/IR/FuncOps.h"
#include "mlir/Dialect/Shape/IR/Shape.h"
#include "mlir/IR/BuiltinOps.h"
#include "mlir/Pass/PassManager.h"
#include "mlir/Pass/PassRegistry.h"

#include <memory>

namespace crest {

namespace {

struct CrestPassOptions : public mlir::PassPipelineOptions<CrestPassOptions> {
  Option<std::string> moduleName{
      *this, "module",
      llvm::cl::desc(
          "Scheme module to load (slash-separated R6RS library name, "
          "e.g. 'passes/my-rewrite')"),
      llvm::cl::init("")};
  Option<std::string> logLevel{
      *this, "log-level",
      llvm::cl::desc(
          "Logging level: trace, debug, info, warning, error, fatal"),
      llvm::cl::init("warning")};
};

// The actual pass — an OperationPass<ModuleOp> that loads and runs a Scheme
// library.
struct CrestPass : public mlir::OperationPass<mlir::ModuleOp> {
  MLIR_DEFINE_EXPLICIT_INTERNAL_INLINE_TYPE_ID(CrestPass)

  CrestPass(std::string moduleName, std::string logLevel)
      : mlir::OperationPass<mlir::ModuleOp>(mlir::TypeID::get<CrestPass>()),
        moduleName_(std::move(moduleName)), logLevel_(std::move(logLevel)) {}

  CrestPass(const CrestPass& other)
      : mlir::OperationPass<mlir::ModuleOp>(other),
        moduleName_(other.moduleName_), logLevel_(other.logLevel_) {}

  llvm::StringRef getName() const override { return "crest-pass"; }

  std::unique_ptr<mlir::Pass> clonePass() const override {
    return std::make_unique<CrestPass>(*this);
  }

  void getDependentDialects(mlir::DialectRegistry& registry) const override {
    registry.insert<mlir::func::FuncDialect, mlir::shape::ShapeDialect>();
  }

  void runOnOperation() override {
    if (moduleName_.empty()) {
      getOperation().emitError("Scheme module name not specified. "
                               "Use --crest-pass=\"module=<name>\"");
      return signalPassFailure();
    }

    auto level = parseLogLevel(logLevel_);
    auto interp = ChezSchemeInterpreter::instance(
        level, crest::registerMlirForeignFunctions);
    interp->setLogLevel(level);

    if (!interp->importLibrary(moduleName_)) {
      auto err = getOperation().emitError("Failed to import " + moduleName_);
      auto dirs = interp->getLibraryDirectories();
      if (!dirs.empty()) {
        err << " (library-directories: " << dirs << ")";
      }
      return signalPassFailure();
    }

    interp->callPassFunction("run-pass", getOperation());
  }

private:
  std::string moduleName_;
  std::string logLevel_;
};

} // namespace

void registerCrestPass() {
  mlir::PassPipelineRegistration<CrestPassOptions>(
      "crest-pass",
      "Run a pass implemented in Scheme via the CREST interpreter. "
      "Options: module=<slash-separated-R6RS-name>, log-level=<level>",
      [](mlir::OpPassManager& pm, const CrestPassOptions& opts) {
        pm.addPass(std::make_unique<CrestPass>(opts.moduleName, opts.logLevel));
      });
}

} // namespace crest
