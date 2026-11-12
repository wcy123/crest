/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/ExecutionEngine/ExecutionEngine.h

#include "ExecutionEngine.h"
#include "../Support/CrestObject.h"
#include "../Support/SchemeWrapper.h"
#include "llvm/Support/TargetSelect.h"
#include "mlir/ExecutionEngine/ExecutionEngine.h"
#include "mlir/ExecutionEngine/OptUtils.h"
#include "mlir/IR/BuiltinOps.h"
#include "mlir/Target/LLVMIR/Dialect/Builtin/BuiltinToLLVMIRTranslation.h"
#include "mlir/Target/LLVMIR/Dialect/LLVMIR/LLVMToLLVMIRTranslation.h"
#include <memory>

namespace crest {

void registerExecutionEngineBindings() {
  // mlir::ExecutionEngine::create: JIT-compile an MLIR module.
  // (module-ptr opt-level) → CrestBox<unique_ptr<ExecutionEngine>>* uptr, 0 on
  // failure
  // LEAK WARNING: the box is on the C++ heap and only the caller frees it. Use
  // with-ExecutionEngine, which frees it after its body; a box that is never
  // freed leaks.
  Sregister_symbol(
      "mlir::ExecutionEngine::create",
      (void*)+[](uint64_t module_ptr, int opt_level) -> uint64_t {
        auto* op = reinterpret_cast<mlir::Operation*>(module_ptr);
        auto module = mlir::cast<mlir::ModuleOp>(op);
        auto* ctx = module->getContext();

        llvm::InitializeNativeTarget();
        llvm::InitializeNativeTargetAsmPrinter();

        mlir::registerBuiltinDialectTranslation(*ctx);
        mlir::registerLLVMDialectTranslation(*ctx);

        mlir::ExecutionEngineOptions opts;
        auto transformer = mlir::makeOptimizingTransformer(
            static_cast<unsigned>(opt_level), /*sizeLevel=*/0,
            /*targetMachine=*/nullptr);
        opts.transformer = transformer;
        auto maybeEngine = mlir::ExecutionEngine::create(module, opts);
        if (!maybeEngine) {
          llvm::consumeError(maybeEngine.takeError());
          return 0;
        }
        // Store the unique_ptr inside CrestBox<unique_ptr<ExecutionEngine>>.
        auto* owned = new CrestBox<std::unique_ptr<mlir::ExecutionEngine>>(
            std::move(*maybeEngine));
        return reinterpret_cast<uint64_t>(owned);
      });

  // mlir::ExecutionEngine::invoke: call a named function in the JIT.
  // (engine-ptr name-str) → int (0=success, nonzero=error)
  Sregister_symbol(
      "mlir::ExecutionEngine::invoke",
      (void*)+[](uint64_t engine_ptr, const char* name) -> int {
        auto& engine_uptr =
            crest::CrestBox<std::unique_ptr<mlir::ExecutionEngine>>::inner(
                engine_ptr, "mlir::ExecutionEngine::invoke");
        auto result = engine_uptr->invokePacked(name);
        if (result) {
          llvm::consumeError(std::move(result));
          return -1;
        }
        return 0;
      });
}

} // namespace crest
