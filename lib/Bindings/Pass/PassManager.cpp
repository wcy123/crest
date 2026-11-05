/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/Pass/PassManager.h

#include "PassManager.h"
#include "../Support/CrestObject.h"
#include "../Support/SchemeWrapper.h"
#include "mlir/Pass/Pass.h"
#include "mlir/Pass/PassManager.h"

namespace crest {

void registerPassPassManagerBindings() {
  /// ctx_ptr: CrestBox<MLIRContext>* | MLIRContext* →
  /// CrestBox<mlir::PassManager>*
  Sregister_symbol(
      "mlir::PassManager::new", (void*)+[](uint64_t ctx_ptr) -> uint64_t {
        if (!ctx_ptr) {
          scheme_error("mlir::PassManager::new", "null MLIRContext pointer");
        }
        return reinterpret_cast<uint64_t>(new CrestBox<mlir::PassManager>(
            crest::as_ptr<mlir::MLIRContext>(ctx_ptr, __func__)));
      });

  // Moves the pass out of CrestBox<unique_ptr<Pass>> into the PassManager.
  // Calling addPass twice with the same holder is an error (moved-from ==
  // null).
  /// pm_ptr: CrestBox<mlir::PassManager>*, pass_ptr:
  /// CrestBox<unique_ptr<Pass>>*
  Sregister_symbol(
      "mlir::PassManager::addPass",
      (void*)+[](uint64_t pm_ptr, uint64_t pass_ptr) -> void {
        auto& pm = crest::CrestBox<mlir::PassManager>::inner(
            pm_ptr, "mlir::PassManager::addPass");
        auto& pass = crest::CrestBox<std::unique_ptr<mlir::Pass>>::inner(
            pass_ptr, "mlir::PassManager::addPass");
        if (!pass) {
          scheme_error("mlir::PassManager::addPass",
                       "pass already consumed by a previous addPass call");
        }
        pm.addPass(std::move(pass));
      });

  /// pm_ptr: CrestBox<mlir::PassManager>*, module_ptr: mlir::Operation* → 1
  /// (success) | 0 (failure)
  Sregister_symbol(
      "mlir::PassManager::run!",
      (void*)+[](uint64_t pm_ptr, uint64_t module_ptr) -> int {
        auto& pm = crest::CrestBox<mlir::PassManager>::inner(
            pm_ptr, "mlir::PassManager::run!");
        auto* op = reinterpret_cast<mlir::Operation*>(module_ptr);
        return mlir::succeeded(pm.run(op)) ? 1 : 0;
      });

  /// pm_ptr: CrestBox<mlir::PassManager>*, enabled: bool (non-zero = true)
  Sregister_symbol(
      "mlir::PassManager::enableVerifier",
      (void*)+[](uint64_t pm_ptr, int enabled) -> void {
        crest::CrestBox<mlir::PassManager>::inner(
            pm_ptr, "mlir::PassManager::enableVerifier")
            .enableVerifier(enabled != 0);
      });

  // Nest a PassManager on the given op name; returns raw OpPassManager* (not
  // owned). pm_ptr: CrestBox<mlir::PassManager>*, op_name: string →
  // OpPassManager* uptr
  Sregister_symbol(
      "mlir::PassManager::nest",
      (void*)+[](uint64_t pm_ptr, const char* op_name) -> uint64_t {
        auto& pm = crest::CrestBox<mlir::PassManager>::inner(
            pm_ptr, "mlir::PassManager::nest");
        return reinterpret_cast<uint64_t>(&pm.nest(op_name));
      });

  // Add a pass to a nested OpPassManager (raw ptr, not owned).
  // nested_pm_ptr: OpPassManager*, pass_ptr: CrestBox<unique_ptr<Pass>>*
  Sregister_symbol(
      "mlir::OpPassManager::addPass",
      (void*)+[](uint64_t nested_pm_ptr, uint64_t pass_ptr) -> void {
        auto* nested = reinterpret_cast<mlir::OpPassManager*>(nested_pm_ptr);
        auto& pass = crest::CrestBox<std::unique_ptr<mlir::Pass>>::inner(
            pass_ptr, "mlir::OpPassManager::addPass");
        if (!pass) {
          scheme_error("mlir::OpPassManager::addPass",
                       "pass already consumed by a previous addPass call");
        }
        nested->addPass(std::move(pass));
      });
}

} // namespace crest
