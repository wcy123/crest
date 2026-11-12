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
  register_binding(
      "mlir::DialectRegistry::insert<mlir::LLVM::LLVMDialect>",
      [](uint64_t registry_ptr) -> llvm::Error {
        CREST_TRY(
            crest_lookup1,
            crest::CrestBox<mlir::DialectRegistry>::tryInner(
                registry_ptr,
                "mlir::DialectRegistry::insert<mlir::LLVM::LLVMDialect>"));

        crest_lookup1.insert<mlir::LLVM::LLVMDialect>();
        return llvm::Error::success();
      });

  // Register LLVM inliner interface into a DialectRegistry.
  // (registry-ptr) → void
  register_binding(
      "mlir::LLVM::registerInlinerInterface",
      [](uint64_t registry_ptr) -> llvm::Error {
        CREST_TRY(crest_lookup1,
                  crest::CrestBox<mlir::DialectRegistry>::tryInner(
                      registry_ptr, "mlir::LLVM::registerInlinerInterface"));

        mlir::LLVM::registerInlinerInterface(crest_lookup1);
        return llvm::Error::success();
      });
}

} // namespace crest
