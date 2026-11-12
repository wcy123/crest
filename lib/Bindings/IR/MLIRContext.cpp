/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */
// Mirrors mlir/IR/MLIRContext.h

#include "MLIRContext.h"
#include "../Support/Result.h"
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
  /// → CrestBox<mlir::MLIRContext>*
  // LEAK WARNING: the box is on the C++ heap and only the caller frees it. Use
  // with-MLIRContext, which frees it after its body. A context made by calling
  // this directly and never freed leaks.
  Sregister_symbol(
      "mlir::MLIRContext::new", (void*)+[]() -> ptr {
        // Scheme callbacks (verifiers, folders, patterns) cannot run on MLIR's
        // worker threads, so a context made from Scheme is single-threaded.
        auto* box = new CrestBox<mlir::MLIRContext>();
        box->inner().disableMultithreading();
        return Sunsigned64(reinterpret_cast<uint64_t>(box));
      });

  /// registry_ptr: CrestBox<mlir::DialectRegistry>* →
  /// CrestBox<mlir::MLIRContext>*
  // LEAK WARNING: as for mlir::MLIRContext::new: use with-MLIRContext.
  Sregister_symbol(
      "mlir::MLIRContext::new/registry",
      (void*)+[](uint64_t registry_ptr) -> ptr {
        auto* registry_box =
            crest::CrestBox<mlir::DialectRegistry>::inner(registry_ptr);
        if (!registry_box) {
          return scheme_error(
              "mlir::MLIRContext::new/registry",
              "null pointer or not a CrestBox<mlir::DialectRegistry>");
        }
        auto& registry = *registry_box;
        auto* box = new CrestBox<mlir::MLIRContext>(registry);
        box->inner().disableMultithreading();
        return Sunsigned64(reinterpret_cast<uint64_t>(box));
      });

  Sregister_symbol(
      "mlir::MLIRContext::allowUnregisteredDialects",
      (void*)+[](uint64_t ctx_ptr, int allow) -> ptr {
        auto* crest_lookup1 = crest::as_context(ctx_ptr);
        if (!crest_lookup1) {
          return scheme_error("mlir::MLIRContext::allowUnregisteredDialects",
                              "null MLIRContext pointer");
        }

        crest_lookup1->allowUnregisteredDialects(allow != 0);
        return Svoid;
      });
  Sregister_symbol(
      "mlir::MLIRContext::allowsUnregisteredDialects",
      (void*)+[](uint64_t ctx_ptr) -> ptr {
        auto* crest_lookup1 = crest::as_context(ctx_ptr);
        if (!crest_lookup1) {
          return scheme_error("mlir::MLIRContext::allowsUnregisteredDialects",
                              "null MLIRContext pointer");
        }

        return Sinteger64(crest_lookup1->allowsUnregisteredDialects() ? 1 : 0);
      });
  Sregister_symbol(
      "mlir::MLIRContext::enableMultithreading",
      (void*)+[](uint64_t ctx_ptr, int enable) -> ptr {
        auto* crest_lookup1 = crest::as_context(ctx_ptr);
        if (!crest_lookup1) {
          return scheme_error("mlir::MLIRContext::enableMultithreading",
                              "null MLIRContext pointer");
        }

        crest_lookup1->enableMultithreading(enable != 0);
        return Svoid;
      });
  Sregister_symbol(
      "mlir::MLIRContext::disableMultithreading",
      (void*)+[](uint64_t ctx_ptr, int disable) -> ptr {
        auto* crest_lookup1 = crest::as_context(ctx_ptr);
        if (!crest_lookup1) {
          return scheme_error("mlir::MLIRContext::disableMultithreading",
                              "null MLIRContext pointer");
        }

        crest_lookup1->disableMultithreading(disable != 0);
        return Svoid;
      });
  Sregister_symbol(
      "mlir::MLIRContext::isMultithreadingEnabled",
      (void*)+[](uint64_t ctx_ptr) -> ptr {
        auto* crest_lookup1 = crest::as_context(ctx_ptr);
        if (!crest_lookup1) {
          return scheme_error("mlir::MLIRContext::isMultithreadingEnabled",
                              "null MLIRContext pointer");
        }

        return Sinteger64(crest_lookup1->isMultithreadingEnabled() ? 1 : 0);
      });
  Sregister_symbol(
      "mlir::MLIRContext::getOrLoadDialect",
      (void*)+[](uint64_t ctx_ptr, const char* ns) -> ptr {
        auto* crest_lookup1 = crest::as_context(ctx_ptr);
        if (!crest_lookup1) {
          return scheme_error("mlir::MLIRContext::getOrLoadDialect",
                              "null MLIRContext pointer");
        }

        return Sunsigned64(
            reinterpret_cast<uint64_t>(crest_lookup1->getOrLoadDialect(ns)));
      });
  Sregister_symbol(
      "mlir::MLIRContext::loadAllAvailableDialects",
      (void*)+[](uint64_t ctx_ptr) -> ptr {
        auto* crest_lookup1 = crest::as_context(ctx_ptr);
        if (!crest_lookup1) {
          return scheme_error("mlir::MLIRContext::loadAllAvailableDialects",
                              "null MLIRContext pointer");
        }

        crest_lookup1->loadAllAvailableDialects();
        return Svoid;
      });
  Sregister_symbol(
      "mlir::MLIRContext::printOpOnDiagnostic",
      (void*)+[](uint64_t ctx_ptr, int enable) -> ptr {
        auto* crest_lookup1 = crest::as_context(ctx_ptr);
        if (!crest_lookup1) {
          return scheme_error("mlir::MLIRContext::printOpOnDiagnostic",
                              "null MLIRContext pointer");
        }

        crest_lookup1->printOpOnDiagnostic(enable != 0);
        return Svoid;
      });
  Sregister_symbol(
      "mlir::MLIRContext::shouldPrintOpOnDiagnostic",
      (void*)+[](uint64_t ctx_ptr) -> ptr {
        auto* crest_lookup1 = crest::as_context(ctx_ptr);
        if (!crest_lookup1) {
          return scheme_error("mlir::MLIRContext::shouldPrintOpOnDiagnostic",
                              "null MLIRContext pointer");
        }

        return Sinteger64(crest_lookup1->shouldPrintOpOnDiagnostic() ? 1 : 0);
      });
  Sregister_symbol(
      "mlir::MLIRContext::printStackTraceOnDiagnostic",
      (void*)+[](uint64_t ctx_ptr, int enable) -> ptr {
        auto* crest_lookup1 = crest::as_context(ctx_ptr);
        if (!crest_lookup1) {
          return scheme_error("mlir::MLIRContext::printStackTraceOnDiagnostic",
                              "null MLIRContext pointer");
        }

        crest_lookup1->printStackTraceOnDiagnostic(enable != 0);
        return Svoid;
      });

  // LEAK WARNING: the module belongs to nobody. The caller must erase it. Use
  // with-mlir::OwningOpRef, which erases it after its body; a module that is
  // never erased leaks.
  Sregister_symbol(
      "mlir::parseSourceFile",
      (void*)+[](uint64_t ctx_ptr, const char* filename) -> ptr {
        auto* ctx = crest::as_context(ctx_ptr);
        if (!ctx) {
          return scheme_error("mlir::parseSourceFile",
                              "null MLIRContext pointer");
        }
        // verifyAfterParse=false: skip structural verification so that
        // dynamic ops without Terminator/HasParent traits can be parsed.
        mlir::ParserConfig config(ctx, /*verifyAfterParse=*/false);
        mlir::OwningOpRef<mlir::ModuleOp> module =
            mlir::parseSourceFile<mlir::ModuleOp>(filename, config);
        if (!module) {
          return Sunsigned64(0);
        }
        return Sunsigned64(
            reinterpret_cast<uint64_t>(module.release().getOperation()));
      });
}
mlir::MLIRContext* as_context(uint64_t address) {
  if (!address) {
    return nullptr;
  }
  auto* obj = reinterpret_cast<crest::CrestObject*>(address);
  if (obj->isa<crest::CrestBox<mlir::MLIRContext>>()) {
    return &static_cast<crest::CrestBox<mlir::MLIRContext>*>(obj)->inner();
  }
  return reinterpret_cast<mlir::MLIRContext*>(address);
}

} // namespace crest
