/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/Dialect/LLVMIR/LLVMDialect.h

#include "LLVMDialect.h"
#include "../../../Support/CrestObject.h"
#include "../../../Support/Result.h"
#include "../../../Support/SchemeWrapper.h"
#include "mlir/Dialect/LLVMIR/LLVMDialect.h"
#include "mlir/Dialect/LLVMIR/Transforms/InlinerInterfaceImpl.h"
#include "mlir/IR/DialectRegistry.h"

namespace crest {

void registerDialectLLVMIRIRLLVMDialectBindings() {
  // Register LLVMDialect into a DialectRegistry.
  // (registry-ptr) → void
  Sregister_symbol(
      "mlir::DialectRegistry::insert<mlir::LLVM::LLVMDialect>",
      (void*)+[](uint64_t registry_ptr) -> ptr {
        auto* crest_lookup1_box =
            crest::CrestBox<mlir::DialectRegistry>::inner(registry_ptr);
        if (!crest_lookup1_box) {
          return scheme_error(
              "mlir::DialectRegistry::insert<mlir::LLVM::LLVMDialect>",
              "null pointer or not a CrestBox<mlir::DialectRegistry>");
        }
        auto& crest_lookup1 = *crest_lookup1_box;

        crest_lookup1.insert<mlir::LLVM::LLVMDialect>();
        return Svoid;
      });

  // Register LLVM inliner interface into a DialectRegistry.
  // (registry-ptr) → void
  Sregister_symbol(
      "mlir::LLVM::registerInlinerInterface",
      (void*)+[](uint64_t registry_ptr) -> ptr {
        auto* crest_lookup1_box =
            crest::CrestBox<mlir::DialectRegistry>::inner(registry_ptr);
        if (!crest_lookup1_box) {
          return scheme_error(
              "mlir::LLVM::registerInlinerInterface",
              "null pointer or not a CrestBox<mlir::DialectRegistry>");
        }
        auto& crest_lookup1 = *crest_lookup1_box;

        mlir::LLVM::registerInlinerInterface(crest_lookup1);
        return Svoid;
      });
}

} // namespace crest
