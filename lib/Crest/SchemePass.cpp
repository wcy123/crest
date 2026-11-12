/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */
// Passes written in Scheme — lib/Crest/SchemePass.cpp

#include "SchemePass.h"
#include "../Bindings/Support/Result.h"
#include "../Bindings/Support/SchemeWrapper.h"
#include "CurrentContext.h"
#include "mlir/Pass/Pass.h"
#include <memory>
#include <string>

namespace crest {

namespace {

// An operation pass that runs on any op (a nested PassManager chooses where)
// and calls the entry point of a Scheme foreign-callable int(uptr op): 0 fails
// the pass, any other number is success. An error of the body is a diagnostic
// at its Scheme source, in the context of the op (set below), and the callable
// answers 0. The callable is made once for the define-pass, so every pass made
// from it shares it and nothing is released.
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
    auto interpreter = ChezSchemeInterpreter::instance();
    CurrentContextScope scope(*interpreter, getOperation()->getContext());
    if (callback_(reinterpret_cast<uint64_t>(getOperation())) == 0) {
      signalPassFailure();
    }
  }

private:
  std::string name_;
  int (*callback_)(uint64_t op);
};

} // namespace

void registerCrestSchemePassBindings() {
  // crest::createSchemePass (string name) (uptr entry) → mlir::Pass* uptr
  //
  // The pass manager that the pass is added to owns it
  // (mlir::OpPassManager::addPass).
  //
  // `entry` is the entry point of the foreign-callable that define-pass made,
  // once, for the body of the pass.
  Sregister_symbol(
      "crest::createSchemePass",
      (void*)+[](const char* name, uint64_t entry) -> ptr {
        return Sunsigned64(reinterpret_cast<uint64_t>(static_cast<mlir::Pass*>(
            new SchemePass(name, reinterpret_cast<int (*)(uint64_t)>(entry)))));
      });
}

} // namespace crest
