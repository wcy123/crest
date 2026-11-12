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
  register_binding(
      "mlir::PassManager::new",
      [](uint64_t ctx_ptr) -> llvm::Expected<uint64_t> {
        if (!ctx_ptr) {
          return fail("mlir::PassManager::new",
                      llvm::Twine("null MLIRContext pointer"));
        }
        CREST_TRY(crest_lookup1,
                  crest::try_as_ptr<mlir::MLIRContext>(ctx_ptr, __func__));

        return reinterpret_cast<uint64_t>(
            new CrestBox<mlir::PassManager>(crest_lookup1));
      });

  // The pass manager takes ownership of the pass, as in C++, where addPass
  // takes a std::unique_ptr<Pass>. A create...Pass binding answers a raw
  // mlir::Pass* that nothing owns yet, so this is where ownership starts.
  // Adding the same pass twice gives it two owners: the caller must not.
  /// pm_ptr: CrestBox<mlir::PassManager>*, pass_ptr: mlir::Pass*
  // LEAK WARNING: a pass that is made by a create...Pass binding and never
  // added to a pass manager leaks: nothing else owns it.
  register_binding("mlir::PassManager::addPass",
                   [](uint64_t pm_ptr, uint64_t pass_ptr) -> llvm::Error {
                     CREST_TRY(pm, crest::CrestBox<mlir::PassManager>::tryInner(
                                       pm_ptr, "mlir::PassManager::addPass"));
                     if (!pass_ptr) {
                       return fail("mlir::PassManager::addPass",
                                   llvm::Twine("null pass pointer"));
                     }
                     pm.addPass(std::unique_ptr<mlir::Pass>(
                         reinterpret_cast<mlir::Pass*>(pass_ptr)));
                     return llvm::Error::success();
                   });

  /// pm_ptr: CrestBox<mlir::PassManager>*, module_ptr: mlir::Operation* → 1
  /// (success) | 0 (failure)
  register_binding(
      "mlir::PassManager::run!",
      [](uint64_t pm_ptr, uint64_t module_ptr) -> llvm::Expected<int> {
        CREST_TRY(pm, crest::CrestBox<mlir::PassManager>::tryInner(
                          pm_ptr, "mlir::PassManager::run!"));
        auto* op = reinterpret_cast<mlir::Operation*>(module_ptr);
        return mlir::succeeded(pm.run(op)) ? 1 : 0;
      });

  /// pm_ptr: CrestBox<mlir::PassManager>*, enabled: bool (non-zero = true)
  register_binding("mlir::PassManager::enableVerifier",
                   [](uint64_t pm_ptr, int enabled) -> llvm::Error {
                     CREST_TRY(
                         crest_lookup1,
                         crest::CrestBox<mlir::PassManager>::tryInner(
                             pm_ptr, "mlir::PassManager::enableVerifier"));

                     crest_lookup1.enableVerifier(enabled != 0);
                     return llvm::Error::success();
                   });

  // Nest a PassManager on the given op name; returns raw OpPassManager* (not
  // owned). pm_ptr: CrestBox<mlir::PassManager>*, op_name: string →
  // OpPassManager* uptr
  register_binding(
      "mlir::PassManager::nest",
      [](uint64_t pm_ptr, const char* op_name) -> llvm::Expected<uint64_t> {
        CREST_TRY(pm, crest::CrestBox<mlir::PassManager>::tryInner(
                          pm_ptr, "mlir::PassManager::nest"));
        return reinterpret_cast<uint64_t>(&pm.nest(op_name));
      });

  // Add a pass to a nested OpPassManager (raw ptr, not owned); the pass manager
  // takes ownership of the pass, as above.
  // nested_pm_ptr: OpPassManager*, pass_ptr: mlir::Pass*
  register_binding(
      "mlir::OpPassManager::addPass",
      [](uint64_t nested_pm_ptr, uint64_t pass_ptr) -> llvm::Error {
        auto* nested = reinterpret_cast<mlir::OpPassManager*>(nested_pm_ptr);
        if (!pass_ptr) {
          return fail("mlir::OpPassManager::addPass",
                      llvm::Twine("null pass pointer"));
        }
        nested->addPass(std::unique_ptr<mlir::Pass>(
            reinterpret_cast<mlir::Pass*>(pass_ptr)));
        return llvm::Error::success();
      });
}

} // namespace crest
