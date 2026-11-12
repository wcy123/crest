/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/Target/LLVMIR/Export.h

#include "Export.h"
#include "../../Support/CrestObject.h"
#include "../../Support/Result.h"
#include "../../Support/SchemeWrapper.h"
#include "llvm/ExecutionEngine/Orc/JITTargetMachineBuilder.h"
#include "llvm/IR/LLVMContext.h"
#include "llvm/IR/Module.h"
#include "llvm/Support/TargetSelect.h"
#include "llvm/Support/raw_ostream.h"
#include "mlir/ExecutionEngine/ExecutionEngine.h"
#include "mlir/ExecutionEngine/OptUtils.h"
#include "mlir/IR/BuiltinOps.h"
#include "mlir/Target/LLVMIR/Dialect/Builtin/BuiltinToLLVMIRTranslation.h"
#include "mlir/Target/LLVMIR/Dialect/LLVMIR/LLVMToLLVMIRTranslation.h"
#include "mlir/Target/LLVMIR/Export.h"
#include <cstdlib>
#include <cstring>

// Both bindings answer the IR text as a std::string, which the registration
// (Result.h) turns into a Scheme string. They used to answer a malloc'd buffer
// that Scheme had to copy and free: a Scheme `string` result copies the text
// and never frees the buffer, which leaked the whole IR text on every call.

namespace crest {

void registerTargetLLVMIRExportBindings() {
  // mlir::translateModuleToLLVMIR: translate an MLIR module to LLVM IR text.
  // Registers builtin+LLVM dialect translations, then translates.
  // (module-ptr) → the LLVM IR text, as a Scheme string (no buffer to free).
  Sregister_symbol(
      "mlir::translateModuleToLLVMIR", (void*)+[](uint64_t module_ptr) -> ptr {
        auto* op = reinterpret_cast<mlir::Operation*>(module_ptr);
        auto module = mlir::cast<mlir::ModuleOp>(op);
        auto* ctx = module->getContext();

        mlir::registerBuiltinDialectTranslation(*ctx);
        mlir::registerLLVMDialectTranslation(*ctx);

        llvm::LLVMContext llvmCtx;
        auto llvmModule = mlir::translateModuleToLLVMIR(module, llvmCtx);
        if (!llvmModule) {
          return scheme_string(std::string("(translation failed)"));
        }

        std::string result;
        llvm::raw_string_ostream os(result);
        llvmModule->print(os, nullptr);
        os.flush();
        return scheme_string(result);
      });

  // mlir::translateModuleToLLVMIR<int>: as above, then what the C++ Toy
  // tutorial's dumpLLVMIR does: set the target triple and data layout of the
  // host and run the optimizing pipeline at the given level (0 to 3).
  // (module-ptr opt-level) → the LLVM IR text, as above.
  Sregister_symbol(
      "mlir::translateModuleToLLVMIR<int>",
      (void*)+[](uint64_t module_ptr, int opt_level) -> ptr {
        auto* op = reinterpret_cast<mlir::Operation*>(module_ptr);
        auto module = mlir::cast<mlir::ModuleOp>(op);
        auto* ctx = module->getContext();

        llvm::InitializeNativeTarget();
        llvm::InitializeNativeTargetAsmPrinter();
        mlir::registerBuiltinDialectTranslation(*ctx);
        mlir::registerLLVMDialectTranslation(*ctx);

        llvm::LLVMContext llvmCtx;
        auto llvmModule = mlir::translateModuleToLLVMIR(module, llvmCtx);
        if (!llvmModule) {
          return scheme_string(std::string("(translation failed)"));
        }

        auto tmBuilder = llvm::orc::JITTargetMachineBuilder::detectHost();
        if (!tmBuilder) {
          llvm::consumeError(tmBuilder.takeError());
          return scheme_error("mlir::translateModuleToLLVMIR<int>",
                              "could not detect the host target machine");
        }
        auto targetMachine = tmBuilder->createTargetMachine();
        if (!targetMachine) {
          llvm::consumeError(targetMachine.takeError());
          return scheme_error("mlir::translateModuleToLLVMIR<int>",
                              "could not create the host target machine");
        }
        mlir::ExecutionEngine::setupTargetTripleAndDataLayout(
            llvmModule.get(), targetMachine->get());

        auto optPipeline = mlir::makeOptimizingTransformer(
            static_cast<unsigned>(opt_level), /*sizeLevel=*/0,
            /*targetMachine=*/nullptr);
        if (auto err = optPipeline(llvmModule.get())) {
          llvm::consumeError(std::move(err));
          return scheme_error("mlir::translateModuleToLLVMIR<int>",
                              "failed to optimize the LLVM module");
        }

        std::string result;
        llvm::raw_string_ostream os(result);
        llvmModule->print(os, nullptr);
        os.flush();
        return scheme_string(result);
      });
}

} // namespace crest
