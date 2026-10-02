/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */
//===- InterpreterTest.cpp - Unit tests for ChezSchemeInterpreter ---------===//

#include "gtest/gtest.h"
#include "../../lib/Interpreter/ChezSchemeInterpreter.h"

using namespace crest;

// Hold one shared_ptr for the entire test binary — Chez Scheme can only be
// initialized once per process. WeakSingleton would try to re-init on each
// test if the shared_ptr were released between tests.
static std::shared_ptr<ChezSchemeInterpreter> g_interp;

class InterpreterTest : public ::testing::Test {
 protected:
  static void SetUpTestSuite() {
    g_interp = ChezSchemeInterpreter::instance();
  }
  static void TearDownTestSuite() {
    g_interp.reset();
  }
};

TEST_F(InterpreterTest, InstanceIsNonNull) {
  ASSERT_NE(g_interp, nullptr);
}

TEST_F(InterpreterTest, SameInstanceReturned) {
  auto b = ChezSchemeInterpreter::instance();
  EXPECT_EQ(g_interp.get(), b.get());
}

TEST_F(InterpreterTest, EvalSimpleExpression) {
  EXPECT_TRUE(g_interp->eval("(+ 1 2)"));
}

TEST(ParseLogLevel, KnownLevels) {
  EXPECT_EQ(parseLogLevel("trace"),   SchemeLogLevel::Trace);
  EXPECT_EQ(parseLogLevel("debug"),   SchemeLogLevel::Debug);
  EXPECT_EQ(parseLogLevel("info"),    SchemeLogLevel::Info);
  EXPECT_EQ(parseLogLevel("warning"), SchemeLogLevel::Warning);
  EXPECT_EQ(parseLogLevel("error"),   SchemeLogLevel::Error);
  EXPECT_EQ(parseLogLevel("fatal"),   SchemeLogLevel::Fatal);
}

TEST(ParseLogLevel, UnknownDefaultsToWarning) {
  EXPECT_EQ(parseLogLevel("bogus"), SchemeLogLevel::Warning);
}
