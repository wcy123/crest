/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */
//===- SchemePassTest.cpp - a Scheme pass on the threads of MLIR ----------===//
//
// A pass nested on func.func runs on several worker threads of MLIR when the
// context allows threads. The thread that runs the pass manager is inactive
// while it waits (the interpreter makes it so, SchemeThreads.h), the workers
// are unknown to Scheme, and the pass allocates, so collections happen while
// the workers run it.

#include "../../lib/Bindings/Support/SchemeWrapper.h"
#include "../../lib/Interpreter/ChezSchemeInterpreter.h"
#include "mlir/Dialect/Func/IR/FuncOps.h"
#include "mlir/IR/BuiltinOps.h"
#include "mlir/IR/DialectRegistry.h"
#include "mlir/IR/MLIRContext.h"
#include "mlir/Parser/Parser.h"
#include "mlir/Pass/Pass.h"
#include "mlir/Pass/PassManager.h"
#include "gtest/gtest.h"
#include <string>

using namespace crest;

namespace {

ptr evalScheme(const std::string& code) {
  ptr port = scheme_call("open-string-input-port", Sstring(code.c_str()));
  ptr expr = scheme_call("read", port);
  return scheme_call("eval", expr);
}

TEST(SchemePassThreads, EveryFunctionIsVisitedOnce) {
  auto interpreter = ChezSchemeInterpreter::instance(
      SchemeLogLevel::Warning, registerMlirForeignFunctions);
  ASSERT_TRUE(
      interpreter->eval("(import (crest callback) (crest support foreign))"));
  ASSERT_TRUE(interpreter->eval("(define pass-count 0)"));
  ASSERT_TRUE(interpreter->eval("(define pass-mutex (make-mutex))"));
  // The body allocates, and counts under a mutex: callbacks run at the same
  // time.
  ASSERT_TRUE(interpreter->eval(
      "(define-c-callable pass-body ((op uptr)) int"
      "  (let loop ([i 0] [garbage '()])"
      "    (when (< i 20000)"
      "      (loop (+ i 1) (if (> (length garbage) 50) '() (cons (make-vector "
      "20 i) garbage)))))"
      "  (with-mutex pass-mutex (set! pass-count (+ pass-count 1)))"
      "  1)"));
  ASSERT_TRUE(
      interpreter->eval("(define create-scheme-pass"
                        "  (crest-foreign-procedure "
                        "\"crest::createSchemePass\" (string uptr) uptr))"));

  constexpr int kFunctions = 64;
  std::string text = "module {\n";
  for (int i = 0; i < kFunctions; ++i) {
    text += "  func.func @f" + std::to_string(i) + "() {\n    return\n  }\n";
  }
  text += "}\n";

  mlir::DialectRegistry registry;
  registry.insert<mlir::func::FuncDialect>();
  mlir::MLIRContext context(registry); // threads enabled
  context.loadAllAvailableDialects();
  ASSERT_TRUE(context.isMultithreadingEnabled());
  mlir::OwningOpRef<mlir::ModuleOp> module =
      mlir::parseSourceString<mlir::ModuleOp>(text, &context);
  ASSERT_TRUE(module);

  for (int run = 0; run < 3; ++run) {
    auto* pass = reinterpret_cast<mlir::Pass*>(Sunsigned64_value(
        evalScheme("(create-scheme-pass \"count\" pass-body)")));
    mlir::PassManager pm(&context);
    pm.nest<mlir::func::FuncOp>().addPass(std::unique_ptr<mlir::Pass>(pass));
    ASSERT_TRUE(mlir::succeeded(pm.run(*module)));
  }
  EXPECT_EQ(Sfixnum_value(evalScheme("pass-count")), 3 * kFunctions);
}

} // namespace
