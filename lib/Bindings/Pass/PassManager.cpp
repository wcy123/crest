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

namespace {

struct OwnedPassManager : public crest::AsCrest<OwnedPassManager> {
  mlir::PassManager pm;
  explicit OwnedPassManager(mlir::MLIRContext* ctx) : pm(ctx) {}
};

} // anonymous namespace

namespace crest {

void registerPassPassManagerBindings() {
  Sregister_symbol(
      "mlir::PassManager::new", (void*)+[](uint64_t ctx_ptr) -> uint64_t {
        if (!ctx_ptr) {
          scheme_error("mlir::PassManager::new", "null MLIRContext pointer");
        }
        return reinterpret_cast<uint64_t>(new OwnedPassManager(
            reinterpret_cast<mlir::MLIRContext*>(ctx_ptr)));
      });

  // Moves the pass out of the CrestPassHolder into the PassManager.
  // Calling addPass twice with the same holder is an error.
  Sregister_symbol(
      "mlir::PassManager::addPass",
      (void*)+[](uint64_t pm_ptr, uint64_t pass_ptr) -> void {
        auto& pm =
            crest_cast<OwnedPassManager>(pm_ptr, "mlir::PassManager::addPass")
                ->pm;
        auto* holder = crest_cast<crest::CrestPassHolder>(
            pass_ptr, "mlir::PassManager::addPass");
        if (!holder->pass) {
          scheme_error("mlir::PassManager::addPass",
                       "pass already consumed by a previous addPass call");
        }
        pm.addPass(std::move(holder->pass));
      });

  Sregister_symbol(
      "mlir::PassManager::run!",
      (void*)+[](uint64_t pm_ptr, uint64_t module_ptr) -> int {
        auto& pm =
            crest_cast<OwnedPassManager>(pm_ptr, "mlir::PassManager::run!")->pm;
        auto* op = reinterpret_cast<mlir::Operation*>(module_ptr);
        return mlir::succeeded(pm.run(op)) ? 1 : 0;
      });

  Sregister_symbol(
      "mlir::PassManager::enableVerifier",
      (void*)+[](uint64_t pm_ptr, int enabled) -> void {
        crest_cast<OwnedPassManager>(pm_ptr,
                                     "mlir::PassManager::enableVerifier")
            ->pm.enableVerifier(enabled != 0);
      });
}

} // namespace crest
