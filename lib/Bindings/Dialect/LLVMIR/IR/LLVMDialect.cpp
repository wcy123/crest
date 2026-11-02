/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/Dialect/LLVMIR/LLVMDialect.h

#include "LLVMDialect.h"
#include "../../../Support/CrestObject.h"
#include "../../../Support/SchemeWrapper.h"
#include "mlir/Dialect/LLVMIR/LLVMDialect.h"
#include "mlir/Dialect/LLVMIR/Transforms/InlinerInterfaceImpl.h"
#include "mlir/IR/DialectRegistry.h"

namespace crest {

void registerDialectLLVMIRIRLLVMDialectBindings() {
  // Register LLVMDialect into a DialectRegistry.
  // (registry-ptr) → void
  Sregister_symbol(
      "mlir::LLVM::LLVMDialect", (void*)+[](uint64_t registry_ptr) -> void {
        crest::as_ref<mlir::DialectRegistry>(registry_ptr,
                                             "mlir::LLVM::LLVMDialect")
            .insert<mlir::LLVM::LLVMDialect>();
      });

  // Register LLVM inliner interface into a DialectRegistry.
  // (registry-ptr) → void
  Sregister_symbol(
      "mlir::LLVM::registerInlinerInterface",
      (void*)+[](uint64_t registry_ptr) -> void {
        mlir::LLVM::registerInlinerInterface(
            crest::as_ref<mlir::DialectRegistry>(
                registry_ptr, "mlir::LLVM::registerInlinerInterface"));
      });
}

} // namespace crest
