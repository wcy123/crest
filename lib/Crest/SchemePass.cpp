/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */
// Passes written in Scheme — lib/Crest/SchemePass.cpp

#include "SchemePass.h"
#include "../Bindings/Support/CrestObject.h"
#include "../Bindings/Support/SchemeWrapper.h"
#include "mlir/Pass/Pass.h"
#include <memory>
#include <string>

namespace crest {

namespace {

// The text of an error that the body of a pass raised, which its callable gives
// (crest::SchemePass::reportFailure) before it answers 0, so that the
// diagnostic can carry it.
std::string g_reported_failure;

// An operation pass that runs on any op (a nested PassManager chooses where)
// and calls the entry point of a Scheme foreign-callable (uptr op) → int: 0
// fails the pass, anything else is success. The callable is made once for the
// define-pass, so every pass made from it shares it and nothing is released.
// Scheme is single-threaded: run it on a context with multithreading disabled
// (contexts made from Scheme are).
class SchemePass : public mlir::OperationPass<> {
public:
  MLIR_DEFINE_EXPLICIT_INTERNAL_INLINE_TYPE_ID(SchemePass)

  SchemePass(std::string name, int (*callback)(uint64_t op))
      : mlir::OperationPass<>(mlir::TypeID::get<SchemePass>()),
        name_(std::move(name)), callback_(callback) {}

  SchemePass(const SchemePass& other)
      : mlir::OperationPass<>(other), name_(other.name_),
        callback_(other.callback_) {}

  llvm::StringRef getName() const override { return name_; }

  std::unique_ptr<mlir::Pass> clonePass() const override {
    return std::make_unique<SchemePass>(*this);
  }

  void runOnOperation() override {
    CREST_REFRESH();
    if (callback_(reinterpret_cast<uint64_t>(getOperation())) == 0) {
      std::string message = std::move(g_reported_failure);
      g_reported_failure.clear();
      if (!message.empty()) {
        getOperation()->emitError() << message;
      }
      signalPassFailure();
    }
  }

private:
  std::string name_;
  int (*callback_)(uint64_t op);
};

} // namespace

void registerCrestSchemePassBindings() {
  // crest::SchemePass::reportFailure (string message)
  //
  // The callable of a pass body calls it with the text of the error the body
  // raised, before it answers 0, so that the diagnostic shows it.
  Sregister_symbol(
      "crest::SchemePass::reportFailure",
      (void*)+[](const char* message) -> void {
        g_reported_failure = message;
      });

  // crest::createSchemePass (string name) (uptr entry) →
  // CrestBox<unique_ptr<Pass>>*
  //
  // `entry` is the entry point of the foreign-callable that define-pass made,
  // once, for the body of the pass.
  Sregister_symbol(
      "crest::createSchemePass",
      (void*)+[](const char* name, uint64_t entry) -> uint64_t {
        return reinterpret_cast<uint64_t>(
            new CrestBox<std::unique_ptr<mlir::Pass>>(
                std::make_unique<SchemePass>(
                    name, reinterpret_cast<int (*)(uint64_t)>(entry))));
      });
}

} // namespace crest
