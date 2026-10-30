/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/Pass/PassManager.h

#include "PassManager.h"
#include "../Support/CrestObject.h"
#include "../Support/SchemeWrapper.h"
#include "../Transforms/InliningUtils.h"
#include "mlir/Pass/Pass.h"
#include "mlir/Pass/PassManager.h"

namespace crest {

void registerPassPassManagerBindings() {
  /// ctx_ptr: CrestOwned<MLIRContext>* | MLIRContext* →
  /// CrestOwned<mlir::PassManager>*
  Sregister_symbol(
      "mlir::PassManager::new", (void*)+[](uint64_t ctx_ptr) -> uint64_t {
        if (!ctx_ptr) {
          scheme_error("mlir::PassManager::new", "null MLIRContext pointer");
        }
        return reinterpret_cast<uint64_t>(new CrestOwned<mlir::PassManager>(
            crest::as_ptr<mlir::MLIRContext>(ctx_ptr, __func__)));
      });

  // Moves the pass out of the CrestPassHolder into the PassManager.
  // Calling addPass twice with the same holder is an error.
  /// pm_ptr: CrestOwned<mlir::PassManager>*, pass_ptr: CrestPassHolder*
  Sregister_symbol(
      "mlir::PassManager::addPass",
      (void*)+[](uint64_t pm_ptr, uint64_t pass_ptr) -> void {
        auto& pm = crest::as_ref<mlir::PassManager>(
            pm_ptr, "mlir::PassManager::addPass");
        auto* holder = crest_cast<crest::CrestPassHolder>(
            pass_ptr, "mlir::PassManager::addPass");
        if (!holder->pass) {
          scheme_error("mlir::PassManager::addPass",
                       "pass already consumed by a previous addPass call");
        }
        pm.addPass(std::move(holder->pass));
      });

  /// pm_ptr: CrestOwned<mlir::PassManager>*, module_ptr: mlir::Operation* → 1
  /// (success) | 0 (failure)
  Sregister_symbol(
      "mlir::PassManager::run!",
      (void*)+[](uint64_t pm_ptr, uint64_t module_ptr) -> int {
        auto& pm =
            crest::as_ref<mlir::PassManager>(pm_ptr, "mlir::PassManager::run!");
        auto* op = reinterpret_cast<mlir::Operation*>(module_ptr);
        return mlir::succeeded(pm.run(op)) ? 1 : 0;
      });

  /// pm_ptr: CrestOwned<mlir::PassManager>*, enabled: bool (non-zero = true)
  Sregister_symbol(
      "mlir::PassManager::enableVerifier",
      (void*)+[](uint64_t pm_ptr, int enabled) -> void {
        crest::as_ref<mlir::PassManager>(pm_ptr,
                                         "mlir::PassManager::enableVerifier")
            .enableVerifier(enabled != 0);
      });
}

} // namespace crest
