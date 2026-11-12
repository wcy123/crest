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
  register_binding("mlir::MLIRContext::new", []() -> uint64_t {
    // Scheme callbacks (verifiers, folders, patterns) cannot run on MLIR's
    // worker threads, so a context made from Scheme is single-threaded.
    auto* box = new CrestBox<mlir::MLIRContext>();
    box->inner().disableMultithreading();
    return reinterpret_cast<uint64_t>(box);
  });

  /// registry_ptr: CrestBox<mlir::DialectRegistry>* →
  /// CrestBox<mlir::MLIRContext>*
  // LEAK WARNING: as for mlir::MLIRContext::new: use with-MLIRContext.
  register_binding("mlir::MLIRContext::new/registry",
                   [](uint64_t registry_ptr) -> llvm::Expected<uint64_t> {
                     CREST_TRY(
                         registry,
                         crest::CrestBox<mlir::DialectRegistry>::inner(
                             registry_ptr, "mlir::MLIRContext::new/registry"));
                     auto* box = new CrestBox<mlir::MLIRContext>(registry);
                     box->inner().disableMultithreading();
                     return reinterpret_cast<uint64_t>(box);
                   });

  register_binding("mlir::MLIRContext::allowUnregisteredDialects",
                   [](uint64_t ctx_ptr, int allow) -> llvm::Error {
                     CREST_TRY(crest_lookup1, crest::as_ptr<mlir::MLIRContext>(
                                                  ctx_ptr, __func__));

                     crest_lookup1->allowUnregisteredDialects(allow != 0);
                     return llvm::Error::success();
                   });
  register_binding("mlir::MLIRContext::allowsUnregisteredDialects",
                   [](uint64_t ctx_ptr) -> llvm::Expected<int> {
                     CREST_TRY(crest_lookup1, crest::as_ptr<mlir::MLIRContext>(
                                                  ctx_ptr, __func__));

                     return crest_lookup1->allowsUnregisteredDialects() ? 1 : 0;
                   });
  register_binding("mlir::MLIRContext::enableMultithreading",
                   [](uint64_t ctx_ptr, int enable) -> llvm::Error {
                     CREST_TRY(crest_lookup1, crest::as_ptr<mlir::MLIRContext>(
                                                  ctx_ptr, __func__));

                     crest_lookup1->enableMultithreading(enable != 0);
                     return llvm::Error::success();
                   });
  register_binding("mlir::MLIRContext::disableMultithreading",
                   [](uint64_t ctx_ptr, int disable) -> llvm::Error {
                     CREST_TRY(crest_lookup1, crest::as_ptr<mlir::MLIRContext>(
                                                  ctx_ptr, __func__));

                     crest_lookup1->disableMultithreading(disable != 0);
                     return llvm::Error::success();
                   });
  register_binding("mlir::MLIRContext::isMultithreadingEnabled",
                   [](uint64_t ctx_ptr) -> llvm::Expected<int> {
                     CREST_TRY(crest_lookup1, crest::as_ptr<mlir::MLIRContext>(
                                                  ctx_ptr, __func__));

                     return crest_lookup1->isMultithreadingEnabled() ? 1 : 0;
                   });
  register_binding(
      "mlir::MLIRContext::getOrLoadDialect",
      [](uint64_t ctx_ptr, const char* ns) -> llvm::Expected<uint64_t> {
        CREST_TRY(crest_lookup1,
                  crest::as_ptr<mlir::MLIRContext>(ctx_ptr, __func__));

        return reinterpret_cast<uint64_t>(crest_lookup1->getOrLoadDialect(ns));
      });
  register_binding("mlir::MLIRContext::loadAllAvailableDialects",
                   [](uint64_t ctx_ptr) -> llvm::Error {
                     CREST_TRY(crest_lookup1, crest::as_ptr<mlir::MLIRContext>(
                                                  ctx_ptr, __func__));

                     crest_lookup1->loadAllAvailableDialects();
                     return llvm::Error::success();
                   });
  register_binding("mlir::MLIRContext::printOpOnDiagnostic",
                   [](uint64_t ctx_ptr, int enable) -> llvm::Error {
                     CREST_TRY(crest_lookup1, crest::as_ptr<mlir::MLIRContext>(
                                                  ctx_ptr, __func__));

                     crest_lookup1->printOpOnDiagnostic(enable != 0);
                     return llvm::Error::success();
                   });
  register_binding("mlir::MLIRContext::shouldPrintOpOnDiagnostic",
                   [](uint64_t ctx_ptr) -> llvm::Expected<int> {
                     CREST_TRY(crest_lookup1, crest::as_ptr<mlir::MLIRContext>(
                                                  ctx_ptr, __func__));

                     return crest_lookup1->shouldPrintOpOnDiagnostic() ? 1 : 0;
                   });
  register_binding("mlir::MLIRContext::printStackTraceOnDiagnostic",
                   [](uint64_t ctx_ptr, int enable) -> llvm::Error {
                     CREST_TRY(crest_lookup1, crest::as_ptr<mlir::MLIRContext>(
                                                  ctx_ptr, __func__));

                     crest_lookup1->printStackTraceOnDiagnostic(enable != 0);
                     return llvm::Error::success();
                   });

  // LEAK WARNING: the module belongs to nobody. The caller must erase it. Use
  // with-mlir::OwningOpRef, which erases it after its body; a module that is
  // never erased leaks.
  register_binding(
      "mlir::parseSourceFile",
      [](uint64_t ctx_ptr, const char* filename) -> llvm::Expected<uint64_t> {
        CREST_TRY(ctx, crest::as_ptr<mlir::MLIRContext>(ctx_ptr, __func__));
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
// Specialisation of as_ptr<mlir::MLIRContext>: accepts CrestBox<MLIRContext>*
// from mlir::MLIRContext::new, or a raw MLIRContext* from MLIR API getters
// (op->getContext(), type.getContext(), etc.). Raw pointers are MLIR-managed
// and need no CrestObject wrapper.
template <>
llvm::Expected<mlir::MLIRContext*> as_ptr<mlir::MLIRContext>(uint64_t ptr_val,
                                                             const char* who) {
  if (!ptr_val) {
    return fail(who, "null MLIRContext pointer");
  }
  auto* obj = reinterpret_cast<crest::CrestObject*>(ptr_val);
  if (obj->isa<crest::CrestBox<mlir::MLIRContext>>()) {
    return &static_cast<crest::CrestBox<mlir::MLIRContext>*>(obj)->inner();
  }
  return reinterpret_cast<mlir::MLIRContext*>(ptr_val);
}

} // namespace crest
