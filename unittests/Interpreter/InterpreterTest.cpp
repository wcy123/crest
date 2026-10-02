/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */
//===- InterpreterTest.cpp - Unit tests for ChezSchemeInterpreter ---------===//

#include "gtest/gtest.h"

// ChezSchemeInterpreter is a private header; include via relative path since
// unittests/ is part of the same build tree.
#include "../../lib/Interpreter/ChezSchemeInterpreter.h"

using namespace crest;

namespace {

TEST(ChezSchemeInterpreter, InstanceIsNonNull) {
  auto interp = ChezSchemeInterpreter::instance();
  ASSERT_NE(interp, nullptr);
}

TEST(ChezSchemeInterpreter, SameInstanceReturned) {
  auto a = ChezSchemeInterpreter::instance();
  auto b = ChezSchemeInterpreter::instance();
  EXPECT_EQ(a.get(), b.get());
}

TEST(ChezSchemeInterpreter, EvalSimpleExpression) {
  auto interp = ChezSchemeInterpreter::instance();
  EXPECT_TRUE(interp->eval("(+ 1 2)"));
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

} // namespace
