/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */
//===- CrestPass.cpp - CREST pass runner for Scheme-defined passes --------===//
//
// Registers --crest-pass via mlir::PassPipelineRegistration (no tablegen).
//
// Options:
//   passes=<name>[,<name>...]          Scheme libraries to load in order.
//                                      Each name is a slash-separated R6RS
//                                      library name, e.g.
//                                      'passes/lower,passes/verify'.
//                                      The last library must export `run-pass`.
//   dialects=<ns>[,<ns>...]            MLIR dialect namespaces to load before
//                                      the Scheme code runs. For C++ dialects.
//   dialects-in-scheme=<lib>[,<lib>...]
//                                      Scheme library paths to import in
//                                      initialize(). Each must export a
//                                      `register-dialects` function that takes
//                                      an MLIRContext* (as uptr) and returns
//                                      #t on success, #f on failure. Use for
//                                      dialects defined via define-dialect.
//   log-level=<level>                  trace|debug|info|warning|error|fatal
//
// Examples:
//   --crest-pass="passes=passes/my-rewrite"
//   --crest-pass="passes=passes/lower,passes/verify dialects=func,my-dialect"
//   --crest-pass="dialects-in-scheme=toy/ch3/toy passes=passes/my-pass"
//   --crest-pass="passes=passes/first" --canonicalize \
//   --crest-pass="passes=passes/second"
//
// Note: within the quoted option string, different options are space-separated
// (MLIR convention), while list values within each option are comma-separated.
// E.g. "passes=a,b dialects=func,shape" has passes=[a,b] and
// dialects=[func,shape].
//
//===----------------------------------------------------------------------===//

#include "../Interpreter/ChezSchemeInterpreter.h"
#include "crest/Passes/Passes.h"
#include "mlir/IR/BuiltinOps.h"
#include "mlir/Pass/PassManager.h"
#include "mlir/Pass/PassRegistry.h"

#include <memory>

namespace crest {

namespace {

struct CrestPassOptions : public mlir::PassPipelineOptions<CrestPassOptions> {
  // Comma-separated list of slash-separated R6RS library names.
  // Uses plain Option<string> (not ListOption) to avoid MLIR's ListOption
  // comma-separator conflicting with the pass-options comma separator.
  // We split on ',' ourselves.
  Option<std::string> passes{
      *this, "passes",
      llvm::cl::desc(
          "Comma-separated Scheme libraries to load in order "
          "(slash-separated R6RS names). The last library must export "
          "`run-pass`. Example: passes=passes/lower,passes/verify"),
      llvm::cl::init("")};
  Option<std::string> dialects{
      *this, "dialects",
      llvm::cl::desc(
          "Comma-separated MLIR dialect namespaces to load before the "
          "Scheme code runs. Example: dialects=func,my-dialect"),
      llvm::cl::init("")};
  Option<std::string> schemeDialects{
      *this, "dialects-in-scheme",
      llvm::cl::desc(
          "Comma-separated Scheme library paths whose register-dialects "
          "function is called in initialize() to register Scheme-defined "
          "dialects. Example: dialects-in-scheme=toy/ch3/toy"),
      llvm::cl::init("")};
  Option<std::string> logLevel{
      *this, "log-level",
      llvm::cl::desc(
          "Logging level: trace, debug, info, warning, error, fatal"),
      llvm::cl::init("warning")};

  static std::vector<std::string> split(llvm::StringRef s) {
    std::vector<std::string> result;
    while (!s.empty()) {
      auto [head, tail] = s.split(',');
      if (!head.empty()) {
        result.push_back(head.str());
      }
      s = tail;
    }
    return result;
  }
};

struct CrestPass : public mlir::OperationPass<mlir::ModuleOp> {
  MLIR_DEFINE_EXPLICIT_INTERNAL_INLINE_TYPE_ID(CrestPass)

  CrestPass(std::vector<std::string> passes, std::vector<std::string> dialects,
            std::vector<std::string> schemeDialects, std::string logLevel)
      : mlir::OperationPass<mlir::ModuleOp>(mlir::TypeID::get<CrestPass>()),
        passes_(std::move(passes)), dialects_(std::move(dialects)),
        schemeDialects_(std::move(schemeDialects)),
        logLevel_(std::move(logLevel)) {}

  CrestPass(const CrestPass& other)
      : mlir::OperationPass<mlir::ModuleOp>(other), passes_(other.passes_),
        dialects_(other.dialects_), schemeDialects_(other.schemeDialects_),
        logLevel_(other.logLevel_) {}

  llvm::StringRef getName() const override { return "crest-pass"; }

  mlir::LogicalResult initialize(mlir::MLIRContext* ctx) override {
    if (!dialects_.empty()) {
      // getOrLoadDialect fatals if called while in multi-threaded execution
      // context (MLIR 22+). initialize() is called sequentially on the main
      // thread, so briefly exiting is safe.
      ctx->exitMultiThreadedExecution();
      for (const auto& ns : dialects_) {
        ctx->getOrLoadDialect(ns);
      }
      ctx->enterMultiThreadedExecution();
    }
    if (!schemeDialects_.empty()) {
      auto level = parseLogLevel(logLevel_);
      auto interp = ChezSchemeInterpreter::instance(
          level, crest::registerMlirForeignFunctions);
      interp->setLogLevel(level);
      for (const auto& lib : schemeDialects_) {
        if (!interp->importLibrary(lib)) {
          llvm::errs() << "[error] Failed to import Scheme dialect library: "
                       << lib << "\n";
          return mlir::failure();
        }
        ptr result = scheme_call(
            Stop_level_value(Sstring_to_symbol("register-dialects")),
            Sunsigned64(reinterpret_cast<uint64_t>(ctx)));
        if (result == Sfalse) {
          llvm::errs() << "[error] register-dialects returned #f for library: "
                       << lib << "\n";
          return mlir::failure();
        }
      }
    }
    return mlir::success();
  }

  std::unique_ptr<mlir::Pass> clonePass() const override {
    return std::make_unique<CrestPass>(*this);
  }

  void runOnOperation() override {
    if (passes_.empty()) {
      getOperation().emitError(
          "No Scheme passes specified. "
          "Use --crest-pass=\"passes=<slash/separated/name>\"");
      return signalPassFailure();
    }

    auto level = parseLogLevel(logLevel_);
    auto interp = ChezSchemeInterpreter::instance(
        level, crest::registerMlirForeignFunctions);
    interp->setLogLevel(level);

    for (const auto& pass : passes_) {
      if (!interp->importLibrary(pass)) {
        auto err = getOperation().emitError(
            "Failed to import Scheme library: " + pass);
        auto dirs = interp->getLibraryDirectories();
        if (!dirs.empty()) {
          err << " (library-directories: " << dirs << ")";
        }
        return signalPassFailure();
      }
    }

    scheme_call("run-pass", getOperation().getOperation());
  }

private:
  std::vector<std::string> passes_;
  std::vector<std::string> dialects_;
  std::vector<std::string> schemeDialects_;
  std::string logLevel_;
};

} // namespace

void registerCrestPass() {
  mlir::PassPipelineRegistration<CrestPassOptions>(
      "crest-pass",
      "Run one or more Scheme passes via the CREST interpreter. "
      "Options: passes=<name>[,<name>...], dialects=<ns>[,<ns>...], "
      "log-level=<level>",
      [](mlir::OpPassManager& pm, const CrestPassOptions& opts) {
        pm.addPass(std::make_unique<CrestPass>(
            CrestPassOptions::split(opts.passes),
            CrestPassOptions::split(opts.dialects),
            CrestPassOptions::split(opts.schemeDialects), opts.logLevel));
      });
}

} // namespace crest
