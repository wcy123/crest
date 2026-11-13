/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */
//===- CrestPass.cpp - CREST pass runner for Scheme-defined passes --------===//
//
// Registers --crest-pass via mlir::PassRegistration (no tablegen).
//
// Options:
//   passes=<name>[,<name>...]          Scheme libraries to load in order.
//                                      Each name is a slash-separated R6RS
//                                      library name, e.g.
//                                      'passes/lower,passes/verify'.
//                                      Some library must export
//                                      `pass-entry-point`.
//   dialects-in-scheme=<name>=<lib>[,<name>=<lib>...]
//                                      Scheme-defined dialects whose ops the
//                                      pass produces (they are not in the
//                                      input). Each is registered in the
//                                      context before the pass runs.
//   log-level=<level>                  trace|debug|info|warning|error|fatal
//
// Examples:
//   --crest-pass="passes=passes/my-rewrite"
//   --crest-pass="passes=passes/lower,passes/verify"
//   --crest-pass="dialects-in-scheme=toy=toy/ch3/toy passes=passes/my-pass"
//   --crest-pass="passes=passes/first" --canonicalize \
//   --crest-pass="passes=passes/second"
//
// Note: within the quoted option string, different options are space-separated
// (MLIR convention), while list values within each option are comma-separated.
// E.g. "passes=a,b log-level=info" has passes=[a,b] and log-level=info.
//
//===----------------------------------------------------------------------===//

#include "../Bindings/Support/Result.h"
#include "../Bindings/Support/SchemeWrapper.h"
#include "../Crest/CurrentContext.h"
#include "../Crest/Dialect.h"
#include "../Interpreter/ChezSchemeInterpreter.h"
#include "crest/Passes/Passes.h"
#include "mlir/IR/BuiltinOps.h"
#include "mlir/IR/DialectRegistry.h"
#include "mlir/Pass/PassManager.h"
#include "mlir/Pass/PassRegistry.h"

#include <memory>
#include <string>

namespace crest {

namespace {

struct CrestPass : public mlir::OperationPass<mlir::ModuleOp> {
  MLIR_DEFINE_EXPLICIT_INTERNAL_INLINE_TYPE_ID(CrestPass)

  CrestPass()
      : mlir::OperationPass<mlir::ModuleOp>(mlir::TypeID::get<CrestPass>()) {}

  CrestPass(const CrestPass& other)
      : mlir::OperationPass<mlir::ModuleOp>(other) {}

  llvm::StringRef getArgument() const override { return "crest-pass"; }
  llvm::StringRef getDescription() const override {
    return "Run one or more Scheme passes via the CREST interpreter";
  }
  llvm::StringRef getName() const override { return "CrestPass"; }

  ListOption<std::string> passes{
      *this, "passes",
      llvm::cl::desc(
          "Scheme libraries to load in order (slash-separated R6RS names). "
          "Some library must export `pass-entry-point`. "
          "Example: passes=passes/lower,passes/verify")};
  ListOption<std::string> schemeDialects{
      *this, "dialects-in-scheme",
      llvm::cl::desc(
          "name=module pairs for Scheme-defined dialects whose ops are "
          "produced by the pass (not in the input IR). "
          "Example: dialects-in-scheme=testd=passes/testd,teste=passes/teste")};
  Option<std::string> logLevel{
      *this, "log-level",
      llvm::cl::desc(
          "Logging level: trace, debug, info, warning, error, fatal"),
      llvm::cl::init("warning")};

  // What the Scheme code creates is not known here, so every dialect that the
  // context can load is loaded before the pass runs: a dialect cannot be loaded
  // while the pass is running.
  mlir::LogicalResult initialize(mlir::MLIRContext* context) override {
    if (!schemeDialects.empty()) {
      mlir::DialectRegistry registry;
      for (const std::string& spec : schemeDialects) {
        auto [dialect_name, module_name] = llvm::StringRef(spec).split('=');
        if (dialect_name.empty() || module_name.empty()) {
          return mlir::emitError(mlir::UnknownLoc::get(context))
                 << "dialects-in-scheme: expected name=module/path, got '"
                 << spec << "'";
        }
        if (auto error = crest::validateSchemeDialect(dialect_name.str(),
                                                      module_name.str())) {
          return mlir::emitError(mlir::UnknownLoc::get(context))
                 << "Failed to import Scheme library: " << module_name << ": "
                 << *error;
        }
        auto [type_id, factory] =
            crest::dialectFactory(dialect_name.str(), module_name.str());
        registry.insert(type_id, dialect_name.str(), factory);
      }
      context->appendDialectRegistry(registry);
    }
    context->loadAllAvailableDialects();
    return mlir::success();
  }

  std::unique_ptr<mlir::Pass> clonePass() const override {
    return std::make_unique<CrestPass>(*this);
  }

  void runOnOperation() override {
    if (passes.empty()) {
      getOperation().emitError(
          "No Scheme passes specified. "
          "Use --crest-pass=\"passes=<slash/separated/name>\"");
      return signalPassFailure();
    }

    auto level = parseLogLevel(logLevel);
    auto interp = ChezSchemeInterpreter::instance(
        level, crest::registerMlirForeignFunctions);
    interp->setLogLevel(level);

    for (const std::string& pass : passes) {
      if (auto importError = interp->importLibrary(pass)) {
        auto err = getOperation().emitError(
            "Failed to import Scheme library: " + pass + ": " + *importError);
        auto dirs = interp->getLibraryDirectories();
        if (!dirs.empty()) {
          err << " (library-directories: " << dirs << ")";
        }
        return signalPassFailure();
      }
    }

    // The pass is run by calling pass-entry-point. Some library of the list
    // exports it (the others may be helpers, as in test/dsl/multi-pass); if
    // none does, the call would go to whatever the name is bound to, or to
    // nothing.
    if (!llvm::any_of(passes, [&](const std::string& pass) {
          return interp->libraryExports(pass, "pass-entry-point");
        })) {
      std::string names;
      for (const std::string& pass : passes) {
        names += (names.empty() ? "" : ", ") + pass;
      }
      getOperation().emitError("Scheme library " + names +
                               " does not export pass-entry-point, which "
                               "--crest-pass=passes= calls to run "
                               "the pass");
      return signalPassFailure();
    }

    // The pass raises no error into this frame: pass-entry-point
    // (define-pass-entry-point) answers #f when its body returned, and
    // (who . why), a symbol and a string, when the body raised an error.
    CurrentContextScope scope(*interp, getOperation()->getContext());
    ptr answer = scheme_call("pass-entry-point", getOperation().getOperation());
    if (Spairp(answer)) {
      std::string who =
          convert_to_cpp<std::string>(Ssymbol_to_string(Scar(answer)));
      std::string why = convert_to_cpp<std::string>(Scdr(answer));
      getOperation().emitError(who.empty() ? why : who + ": " + why);
      return signalPassFailure();
    }
  }
};

} // namespace

void registerCrestPass() { mlir::PassRegistration<CrestPass>(); }

} // namespace crest
