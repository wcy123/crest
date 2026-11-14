/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/Pass/PassManager.h

#include "PassManager.h"
#include "../Support/CrestObject.h"
#include "../Support/Result.h"
#include "../Support/SchemeWrapper.h"
#include "mlir/Pass/Pass.h"
#include "mlir/Pass/PassManager.h"

namespace crest {

void registerPassPassManagerBindings() {
  /// ctx_ptr: CrestBox<MLIRContext>* | MLIRContext* →
  /// CrestBox<mlir::PassManager>*
  // LEAK WARNING: the box is on the C++ heap and only the caller frees it. Use
  // with-PassManager, which frees it after its body.
  Sregister_symbol(
      "mlir::PassManager::new", (void*)+[](uint64_t ctx_ptr) -> ptr {
        if (!ctx_ptr) {
          return scheme_error("mlir::PassManager::new",
                              "null MLIRContext pointer");
        }
        auto* crest_lookup1 = crest::as_context(ctx_ptr);

        return Sunsigned64(reinterpret_cast<uint64_t>(
            new CrestBox<mlir::PassManager>(crest_lookup1)));
      });

  // The pass manager takes ownership of the pass, as in C++, where addPass
  // takes a std::unique_ptr<Pass>. A create...Pass binding answers a raw
  // mlir::Pass* that nothing owns yet, so this is where ownership starts.
  // Adding the same pass twice gives it two owners: the caller must not.
  /// pm_ptr: CrestBox<mlir::PassManager>*, pass_ptr: mlir::Pass*
  // LEAK WARNING: a pass that is made by a create...Pass binding and never
  // added to a pass manager leaks: nothing else owns it.
  Sregister_symbol(
      "mlir::PassManager::addPass",
      (void*)+[](uint64_t pm_ptr, uint64_t pass_ptr) -> ptr {
        auto* pm_box = crest::CrestBox<mlir::PassManager>::inner(pm_ptr);
        if (!pm_box) {
          return scheme_error(
              "mlir::PassManager::addPass",
              "null pointer or not a CrestBox<mlir::PassManager>");
        }
        auto& pm = *pm_box;
        if (!pass_ptr) {
          return scheme_error("mlir::PassManager::addPass",
                              "null pass pointer");
        }
        pm.addPass(std::unique_ptr<mlir::Pass>(
            reinterpret_cast<mlir::Pass*>(pass_ptr)));
        return Svoid;
      });

  /// pm_ptr: CrestBox<mlir::PassManager>*, module_ptr: mlir::Operation* → 1
  /// (success) | 0 (failure)
  Sregister_symbol(
      "mlir::PassManager::run!",
      (void*)+[](uint64_t pm_ptr, uint64_t module_ptr) -> ptr {
        auto* pm_box = crest::CrestBox<mlir::PassManager>::inner(pm_ptr);
        if (!pm_box) {
          return scheme_error(
              "mlir::PassManager::run!",
              "null pointer or not a CrestBox<mlir::PassManager>");
        }
        auto& pm = *pm_box;
        auto* op = reinterpret_cast<mlir::Operation*>(module_ptr);
        return Sinteger64(mlir::succeeded(pm.run(op)) ? 1 : 0);
      });

  /// pm_ptr: CrestBox<mlir::PassManager>*, enabled: bool (non-zero = true)
  Sregister_symbol(
      "mlir::PassManager::enableVerifier",
      (void*)+[](uint64_t pm_ptr, int enabled) -> ptr {
        auto* crest_lookup1_box =
            crest::CrestBox<mlir::PassManager>::inner(pm_ptr);
        if (!crest_lookup1_box) {
          return scheme_error(
              "mlir::PassManager::enableVerifier",
              "null pointer or not a CrestBox<mlir::PassManager>");
        }
        auto& crest_lookup1 = *crest_lookup1_box;

        crest_lookup1.enableVerifier(enabled != 0);
        return Svoid;
      });

  // Nest a PassManager on the given op name; returns raw OpPassManager* (not
  // owned). pm_ptr: CrestBox<mlir::PassManager>*, op_name: string →
  // OpPassManager* uptr
  // LIFETIME WARNING: the OpPassManager that this answers belongs to `pm`. It
  // is freed when `pm` is freed, which is when the with-PassManager that made
  // `pm` ends. Do not use it after that.
  Sregister_symbol(
      "mlir::PassManager::nest",
      (void*)+[](uint64_t pm_ptr, const char* op_name) -> ptr {
        auto* pm_box = crest::CrestBox<mlir::PassManager>::inner(pm_ptr);
        if (!pm_box) {
          return scheme_error(
              "mlir::PassManager::nest",
              "null pointer or not a CrestBox<mlir::PassManager>");
        }
        auto& pm = *pm_box;
        return Sunsigned64(reinterpret_cast<uint64_t>(&pm.nest(op_name)));
      });

  // Add a pass to a nested OpPassManager (raw ptr, not owned); the pass manager
  // takes ownership of the pass, as above.
  // nested_pm_ptr: OpPassManager*, pass_ptr: mlir::Pass*
  Sregister_symbol(
      "mlir::OpPassManager::addPass",
      (void*)+[](uint64_t nested_pm_ptr, uint64_t pass_ptr) -> ptr {
        auto* nested = reinterpret_cast<mlir::OpPassManager*>(nested_pm_ptr);
        if (!pass_ptr) {
          return scheme_error("mlir::OpPassManager::addPass",
                              "null pass pointer");
        }
        nested->addPass(std::unique_ptr<mlir::Pass>(
            reinterpret_cast<mlir::Pass*>(pass_ptr)));
        return Svoid;
      });
}

} // namespace crest
