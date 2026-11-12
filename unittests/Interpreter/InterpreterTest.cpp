/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */
//===- InterpreterTest.cpp - Unit tests for ChezSchemeInterpreter ---------===//

#include "../../lib/Bindings/Support/LockedSchemeObject.h"
#include "../../lib/Interpreter/ChezSchemeInterpreter.h"
#include "gtest/gtest.h"
#include <chrono>
#include <iostream>
#if defined(__GLIBC__)
#  include <malloc.h>
#endif
#if defined(__SSE2__) || defined(_M_X64)
#  include <emmintrin.h>
#endif

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

// A Scheme value from its text.
static ptr evalScheme(const char* code) {
  ptr port = scheme_call("open-string-input-port", Sstring(code));
  ptr expr = scheme_call("read", port);
  return scheme_call("eval", expr);
}

// What crest-make-static-c-callable (scheme/crest/callback.sls) does: make a
// foreign-callable, lock its code object once, answer its address.
static uint64_t makeCallableEntry() {
  return Sunsigned64_value(evalScheme(
      "(let ([code (foreign-callable (lambda (x) (+ x 1)) (int) int)])"
      "  (lock-object code)"
      "  (foreign-callable-entry-point code))"));
}

// C++ calls the C function that Scheme made as it calls any function pointer.
TEST_F(InterpreterTest, CallableCallsTheSchemeProcedure) {
  auto callable = reinterpret_cast<int (*)(int)>(makeCallableEntry());
  ASSERT_NE(callable, nullptr);
  EXPECT_EQ(callable(41), 42);
}

// REGRESSION: scheme_error built its message with a std::ostringstream and a
// std::string, then called the Scheme procedure `error`, which never returns:
// the destructors of both were skipped, and every error leaked about 550 bytes
// of C++ memory. Valgrind showed it. The message must be copied into a Scheme
// string and the C++ objects destroyed before Scheme is called.
#if defined(__GLIBC__)
// The bytes that malloc has given out and not got back. mallinfo2 replaces
// mallinfo (glibc 2.33), which newer glibc marks as deprecated.
static size_t bytesInUse() {
#  if __GLIBC_PREREQ(2, 33)
  return static_cast<size_t>(mallinfo2().uordblks);
#  else
  return static_cast<size_t>(mallinfo().uordblks);
#  endif
}

TEST_F(InterpreterTest, SchemeErrorDoesNotLeakCppMemory) {
  Sregister_symbol(
      "crest::test::raise", (void*)+[]() -> void {
        scheme_error("crest::test", "a message that is long enough to matter",
                     42, "and a second part");
      });
  evalScheme("(define crest-test-raise"
             "  (foreign-procedure \"crest::test::raise\" () void))");
  ptr once = evalScheme("(lambda () (guard (c [#t #f]) (crest-test-raise)))");
  LockedSchemeObject locked(once);
  auto run = [&](int times) {
    for (int i = 0; i < times; ++i) {
      scheme_call(locked.get());
    }
  };
  // The errors themselves are Scheme garbage: collect before and after, so
  // that only memory that C++ lost is left in the difference.
  auto collect = [] {
    for (int i = 0; i < 3; ++i) {
      scheme_call("collect");
    }
  };
  run(100);
  collect();
  size_t before = bytesInUse();
  constexpr int kErrors = 20000;
  run(kErrors);
  collect();
  size_t grown = bytesInUse() - before;
  // Before the repair each error lost about 816 bytes in scheme_error. What is
  // left, about 200 bytes per error, is Chez's own: S_call_help allocates a
  // record for each call from C into Scheme and does not free it when an error
  // leaves through that call (valgrind: malloc in S_call_help). The bound
  // allows for that and not for CREST's own leak. LEAK WARNING: the patch of
  // cmake/patches/chez-release-escaped-frames.patch removes Chez's share of it,
  // but only on a build that applies it (not Windows).
  EXPECT_LT(grown, static_cast<size_t>(kErrors) * 400)
      << grown << " bytes in use more after " << kErrors << " errors";
}
#endif

#if defined(__SSE2__) || defined(_M_X64)
// REGRESSION (Windows x64): Chez Scheme's foreign-callable used to zero the
// upper halves of XMM6-XMM11, which that ABI makes callee-saved (fixed
// upstream, cisco/ChezScheme#1064; see "Chez Scheme pin" in docs/tech-note.md).
// Ten vectors are live across the call, which the compiler keeps in those
// registers (a 16-byte Block::iterator is what LLVM 23 code keeps there).
static volatile float g_vector_seed = 1.0f;

TEST_F(InterpreterTest, CallablePreservesVectorRegisters) {
  auto callable = reinterpret_cast<int (*)(int)>(makeCallableEntry());
  float seed = g_vector_seed;
  __m128 v0 = _mm_set_ps(seed + 1, seed + 2, seed + 3, seed + 4);
  __m128 v1 = _mm_set_ps(seed + 5, seed + 6, seed + 7, seed + 8);
  __m128 v2 = _mm_set_ps(seed + 9, seed + 10, seed + 11, seed + 12);
  __m128 v3 = _mm_set_ps(seed + 13, seed + 14, seed + 15, seed + 16);
  __m128 v4 = _mm_set_ps(seed + 17, seed + 18, seed + 19, seed + 20);
  __m128 v5 = _mm_set_ps(seed + 21, seed + 22, seed + 23, seed + 24);
  __m128 v6 = _mm_set_ps(seed + 25, seed + 26, seed + 27, seed + 28);
  __m128 v7 = _mm_set_ps(seed + 29, seed + 30, seed + 31, seed + 32);
  __m128 v8 = _mm_set_ps(seed + 33, seed + 34, seed + 35, seed + 36);
  __m128 v9 = _mm_set_ps(seed + 37, seed + 38, seed + 39, seed + 40);
  EXPECT_EQ(callable(1), 2);
  const __m128 vectors[10] = {v0, v1, v2, v3, v4, v5, v6, v7, v8, v9};
  for (int i = 0; i < 10; ++i) {
    alignas(16) float lanes[4];
    _mm_store_ps(lanes, vectors[i]);
    for (int lane = 0; lane < 4; ++lane) {
      EXPECT_EQ(lanes[lane], seed + static_cast<float>(4 * i + (4 - lane)))
          << "vector " << i << " lane " << lane;
    }
  }
}
#endif

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
