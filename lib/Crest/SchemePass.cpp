/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */
// Passes written in Scheme — lib/Crest/SchemePass.cpp

#include "SchemePass.h"
#include "../Bindings/Support/CrestObject.h"
#include "../Bindings/Support/LockedSchemeObject.h"
#include "../Bindings/Support/SchemeWrapper.h"
#include "mlir/Pass/Pass.h"
#include <memory>
#include <string>

namespace crest {

namespace {

// An operation pass that runs on any op (a nested PassManager chooses where)
// and calls a Scheme procedure (op) → #f to fail, anything else to succeed.
// Scheme is single-threaded: run it on a context with multithreading disabled
// (contexts made from Scheme are).
class SchemePass : public mlir::OperationPass<> {
public:
  MLIR_DEFINE_EXPLICIT_INTERNAL_INLINE_TYPE_ID(SchemePass)

  SchemePass(std::string name, std::shared_ptr<LockedSchemeObject> callback)
      : mlir::OperationPass<>(mlir::TypeID::get<SchemePass>()),
        name_(std::move(name)), callback_(std::move(callback)) {}

  SchemePass(const SchemePass& other)
      : mlir::OperationPass<>(other), name_(other.name_),
        callback_(other.callback_) {}

  llvm::StringRef getName() const override { return name_; }

  std::unique_ptr<mlir::Pass> clonePass() const override {
    return std::make_unique<SchemePass>(*this);
  }

  void runOnOperation() override {
    ptr result = scheme_call(callback_->get(), getOperation());
    if (result == Sfalse) {
      signalPassFailure();
    }
  }

private:
  std::string name_;
  std::shared_ptr<LockedSchemeObject> callback_;
};

} // namespace

void registerCrestSchemePassBindings() {
  // crest::createSchemePass (string name) (scheme-object procedure) →
  // CrestBox<unique_ptr<Pass>>*
  Sregister_symbol(
      "crest::createSchemePass",
      (void*)+[](const char* name, ptr callback) -> uint64_t {
        if (!Sprocedurep(callback)) {
          scheme_error("crest::createSchemePass",
                       "the pass body must be a procedure");
        }
        auto locked = std::make_shared<LockedSchemeObject>(callback);
        return reinterpret_cast<uint64_t>(
            new CrestBox<std::unique_ptr<mlir::Pass>>(
                std::make_unique<SchemePass>(name, std::move(locked))));
      });
}

} // namespace crest
