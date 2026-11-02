/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/Target/LLVMIR/Export.h

#include "Export.h"
#include "../../Support/CrestObject.h"
#include "../../Support/SchemeWrapper.h"
#include "llvm/IR/LLVMContext.h"
#include "llvm/IR/Module.h"
#include "llvm/Support/raw_ostream.h"
#include "mlir/IR/BuiltinOps.h"
#include "mlir/Target/LLVMIR/Dialect/Builtin/BuiltinToLLVMIRTranslation.h"
#include "mlir/Target/LLVMIR/Dialect/LLVMIR/LLVMToLLVMIRTranslation.h"
#include "mlir/Target/LLVMIR/Export.h"
#include <cstdlib>
#include <cstring>

namespace crest {

void registerTargetLLVMIRExportBindings() {
  // mlir::translateModuleToLLVMIR: translate an MLIR module to LLVM IR text.
  // Registers builtin+LLVM dialect translations, then translates.
  // (module-ptr) → Scheme string (LLVM IR text)
  Sregister_symbol(
      "mlir::translateModuleToLLVMIR",
      (void*)+[](uint64_t module_ptr) -> const char* {
        auto* op = reinterpret_cast<mlir::Operation*>(module_ptr);
        auto module = mlir::cast<mlir::ModuleOp>(op);
        auto* ctx = module->getContext();

        mlir::registerBuiltinDialectTranslation(*ctx);
        mlir::registerLLVMDialectTranslation(*ctx);

        llvm::LLVMContext llvmCtx;
        auto llvmModule = mlir::translateModuleToLLVMIR(module, llvmCtx);
        if (!llvmModule) {
          static const char* kFail = "(translation failed)";
          return kFail;
        }

        std::string result;
        llvm::raw_string_ostream os(result);
        llvmModule->print(os, nullptr);
        os.flush();
        // Chez's foreign-procedure with `string` return type copies the C
        // string.
        char* buf = static_cast<char*>(malloc(result.size() + 1));
        memcpy(buf, result.data(), result.size() + 1);
        return buf;
      });
}

} // namespace crest
