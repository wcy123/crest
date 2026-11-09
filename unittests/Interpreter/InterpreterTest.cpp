/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */
//===- InterpreterTest.cpp - Unit tests for ChezSchemeInterpreter ---------===//

#include "../../lib/Bindings/Support/ForeignCallable.h"
#include "../../lib/Interpreter/ChezSchemeInterpreter.h"
#include "gtest/gtest.h"

using namespace crest;

// Hold one shared_ptr for the entire test binary — Chez Scheme can only be
// initialized once per process. WeakSingleton would try to re-init on each
// test if the shared_ptr were released between tests.
static std::shared_ptr<ChezSchemeInterpreter> g_interp;

class InterpreterTest : public ::testing::Test {
protected:
  static void SetUpTestSuite() { g_interp = ChezSchemeInterpreter::instance(); }
  static void TearDownTestSuite() { g_interp.reset(); }
};

TEST_F(InterpreterTest, InstanceIsNonNull) { ASSERT_NE(g_interp, nullptr); }

TEST_F(InterpreterTest, SameInstanceReturned) {
  auto b = ChezSchemeInterpreter::instance();
  EXPECT_EQ(g_interp.get(), b.get());
}

TEST_F(InterpreterTest, EvalSimpleExpression) {
  EXPECT_TRUE(g_interp->eval("(+ 1 2)"));
}

// What crest-callback-entry-point (scheme/crest/callback.sls) does: make a
// foreign-callable, lock its code object once, answer its address.
static uint64_t makeCallableEntry() {
  ptr port = scheme_call(
      "open-string-input-port",
      Sstring("(let ([code (foreign-callable (lambda (x) (+ x 1)) (int) int)])"
              "  (lock-object code)"
              "  (foreign-callable-entry-point code))"));
  ptr expr = scheme_call("read", port);
  return Sunsigned64_value(scheme_call("eval", expr));
}

TEST_F(InterpreterTest, ForeignCallableCallsTheSchemeProcedure) {
  ForeignCallable<int(int)> callable(makeCallableEntry());
  ASSERT_TRUE(callable);
  EXPECT_EQ(callable(41), 42);
}

TEST_F(InterpreterTest, ForeignCallableUnlocksItsCodeObjectWhenDestroyed) {
  uint64_t entry = makeCallableEntry();
  ptr code = Sforeign_callable_code_object(reinterpret_cast<void*>(entry));
  EXPECT_TRUE(Slocked_objectp(code));
  {
    ForeignCallable<int(int)> callable(entry);
    // Running Scheme may collect garbage; the locked object stays where it is.
    EXPECT_EQ(callable(1), 2);
    EXPECT_TRUE(Slocked_objectp(code));
  }
  EXPECT_FALSE(Slocked_objectp(code));
}

TEST_F(InterpreterTest, ForeignCallableMovedFromDoesNotUnlock) {
  uint64_t entry = makeCallableEntry();
  ptr code = Sforeign_callable_code_object(reinterpret_cast<void*>(entry));
  {
    ForeignCallable<int(int)> first(entry);
    ForeignCallable<int(int)> second(std::move(first));
    EXPECT_FALSE(first);
    EXPECT_TRUE(second);
  }
  EXPECT_FALSE(Slocked_objectp(code));
}

// The callee-saved state of the caller must survive a foreign-callable: on Windows x64 that includes
// xmm6-xmm15. A callable that allocates and computes with flonums runs while ten doubles are live in
// the caller (the compiler keeps them in those registers across the call).
static uint64_t makeBusyCallableEntry() {
  ptr port = scheme_call(
      "open-string-input-port",
      Sstring("(let ([code (foreign-callable"
              "  (lambda (x)"
              "    (let loop ([i 0] [acc 0.0] [l '()])"
              "      (if (< i 5000)"
              "          (loop (+ i 1) (+ acc (* 1.5 (exact->inexact i))) (cons (make-string 3 #\\a) l))"
              "          (if (> acc 0.0) (length l) 0))))"
              "  (int) int)])"
              "  (lock-object code)"
              "  (foreign-callable-entry-point code))"));
  ptr expr = scheme_call("read", port);
  return Sunsigned64_value(scheme_call("eval", expr));
}

static double g_seed = 3.0;

TEST_F(InterpreterTest, ForeignCallablePreservesCalleeSavedFloatingPointRegisters) {
  ForeignCallable<int(int)> callable(makeBusyCallableEntry());
  double a0 = g_seed * 1.5, a1 = g_seed * 2.5, a2 = g_seed * 3.5, a3 = g_seed * 4.5,
         a4 = g_seed * 5.5, a5 = g_seed * 6.5, a6 = g_seed * 7.5, a7 = g_seed * 8.5,
         a8 = g_seed * 9.5, a9 = g_seed * 10.5;
  EXPECT_EQ(callable(1), 5000);
  EXPECT_EQ(a0, g_seed * 1.5);
  EXPECT_EQ(a1, g_seed * 2.5);
  EXPECT_EQ(a2, g_seed * 3.5);
  EXPECT_EQ(a3, g_seed * 4.5);
  EXPECT_EQ(a4, g_seed * 5.5);
  EXPECT_EQ(a5, g_seed * 6.5);
  EXPECT_EQ(a6, g_seed * 7.5);
  EXPECT_EQ(a7, g_seed * 8.5);
  EXPECT_EQ(a8, g_seed * 9.5);
  EXPECT_EQ(a9, g_seed * 10.5);
}

TEST(ParseLogLevel, KnownLevels) {
  EXPECT_EQ(parseLogLevel("trace"), SchemeLogLevel::Trace);
  EXPECT_EQ(parseLogLevel("debug"), SchemeLogLevel::Debug);
  EXPECT_EQ(parseLogLevel("info"), SchemeLogLevel::Info);
  EXPECT_EQ(parseLogLevel("warning"), SchemeLogLevel::Warning);
  EXPECT_EQ(parseLogLevel("error"), SchemeLogLevel::Error);
  EXPECT_EQ(parseLogLevel("fatal"), SchemeLogLevel::Fatal);
}

TEST(ParseLogLevel, UnknownDefaultsToWarning) {
  EXPECT_EQ(parseLogLevel("bogus"), SchemeLogLevel::Warning);
}
