/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */
// Mirrors mlir/IR/MLIRContext.h

#include "MLIRContext.h"
#include "../Support/SchemeWrapper.h"
#include "llvm/Support/SourceMgr.h"
#include "mlir/IR/AsmState.h"
#include "mlir/IR/BuiltinOps.h"
#include "mlir/IR/Dialect.h"
#include "mlir/IR/DialectRegistry.h"
#include "mlir/IR/MLIRContext.h"
#include "mlir/IR/OwningOpRef.h"
#include "mlir/Parser/Parser.h"
#include <cstdint>

namespace crest {
void registerIRMLIRContextBindings() {
  Sregister_symbol(
      "mlir::MLIRContext::new", (void*)+[]() -> uint64_t {
        return reinterpret_cast<uint64_t>(new mlir::MLIRContext());
      });

  Sregister_symbol(
      "mlir::MLIRContext::new/registry",
      (void*)+[](uint64_t registry_ptr) -> uint64_t {
        auto& registry = crest::as_ref<mlir::DialectRegistry>(
            registry_ptr, "mlir::MLIRContext::new/registry");
        return reinterpret_cast<uint64_t>(new mlir::MLIRContext(registry));
      });

  Sregister_symbol(
      "mlir::MLIRContext::allowUnregisteredDialects",
      (void*)+[](uint64_t ctx_ptr, int allow) -> void {
        reinterpret_cast<mlir::MLIRContext*>(ctx_ptr)
            ->allowUnregisteredDialects(allow != 0);
      });
  Sregister_symbol(
      "mlir::MLIRContext::allowsUnregisteredDialects",
      (void*)+[](uint64_t ctx_ptr) -> int {
        return reinterpret_cast<mlir::MLIRContext*>(ctx_ptr)
                       ->allowsUnregisteredDialects()
                   ? 1
                   : 0;
      });
  Sregister_symbol(
      "mlir::MLIRContext::enableMultithreading",
      (void*)+[](uint64_t ctx_ptr, int enable) -> void {
        reinterpret_cast<mlir::MLIRContext*>(ctx_ptr)->enableMultithreading(
            enable != 0);
      });
  Sregister_symbol(
      "mlir::MLIRContext::disableMultithreading",
      (void*)+[](uint64_t ctx_ptr, int disable) -> void {
        reinterpret_cast<mlir::MLIRContext*>(ctx_ptr)->disableMultithreading(
            disable != 0);
      });
  Sregister_symbol(
      "mlir::MLIRContext::isMultithreadingEnabled",
      (void*)+[](uint64_t ctx_ptr) -> int {
        return reinterpret_cast<mlir::MLIRContext*>(ctx_ptr)
                       ->isMultithreadingEnabled()
                   ? 1
                   : 0;
      });
  Sregister_symbol(
      "mlir::MLIRContext::getOrLoadDialect",
      (void*)+[](uint64_t ctx_ptr, const char* ns) -> uint64_t {
        return reinterpret_cast<uint64_t>(
            reinterpret_cast<mlir::MLIRContext*>(ctx_ptr)->getOrLoadDialect(
                ns));
      });
  Sregister_symbol(
      "mlir::MLIRContext::loadAllAvailableDialects",
      (void*)+[](uint64_t ctx_ptr) -> void {
        reinterpret_cast<mlir::MLIRContext*>(ctx_ptr)
            ->loadAllAvailableDialects();
      });
  Sregister_symbol(
      "mlir::MLIRContext::printOpOnDiagnostic",
      (void*)+[](uint64_t ctx_ptr, int enable) -> void {
        reinterpret_cast<mlir::MLIRContext*>(ctx_ptr)->printOpOnDiagnostic(
            enable != 0);
      });
  Sregister_symbol(
      "mlir::MLIRContext::shouldPrintOpOnDiagnostic",
      (void*)+[](uint64_t ctx_ptr) -> int {
        return reinterpret_cast<mlir::MLIRContext*>(ctx_ptr)
                       ->shouldPrintOpOnDiagnostic()
                   ? 1
                   : 0;
      });
  Sregister_symbol(
      "mlir::MLIRContext::printStackTraceOnDiagnostic",
      (void*)+[](uint64_t ctx_ptr, int enable) -> void {
        reinterpret_cast<mlir::MLIRContext*>(ctx_ptr)
            ->printStackTraceOnDiagnostic(enable != 0);
      });

  // mlir::parseSourceFile — parse an MLIR text file; returns Operation* or 0.
  Sregister_symbol(
      "mlir::parseSourceFile",
      (void*)+[](uint64_t ctx_ptr, const char* filename) -> uint64_t {
        auto* ctx = reinterpret_cast<mlir::MLIRContext*>(ctx_ptr);
        // verifyAfterParse=false: skip structural verification so that
        // dynamic ops without Terminator/HasParent traits can be parsed.
        mlir::ParserConfig config(ctx, /*verifyAfterParse=*/false);
        mlir::OwningOpRef<mlir::ModuleOp> module =
            mlir::parseSourceFile<mlir::ModuleOp>(filename, config);
        if (!module) {
          return 0;
        }
        return reinterpret_cast<uint64_t>(module.release().getOperation());
      });
}
} // namespace crest
