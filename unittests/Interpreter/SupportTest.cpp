/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */
//===- SupportTest.cpp - Unit tests for lib/Bindings/Support --------------===//
//
// The handles and answers that every binding uses: the type tag of CrestBox,
// the layout of CArrayRef that Scheme reads by offset, scheme_error, and the
// three symbols that register_builder_binding makes.

#include "../../lib/Bindings/Support/ArrayRef.h"
#include "../../lib/Bindings/Support/BuilderBinding.h"
#include "../../lib/Bindings/Support/CrestObject.h"
#include "../../lib/Bindings/Support/Result.h"
#include "../../lib/Interpreter/ChezSchemeInterpreter.h"
#include "gtest/gtest.h"
#include <memory>
#include <string>

using namespace crest;

// Chez Scheme can only be initialized once per process; this file shares the
// interpreter with InterpreterTest.cpp.
static std::shared_ptr<ChezSchemeInterpreter> g_support_interp;

class SupportTest : public ::testing::Test {
protected:
  static void SetUpTestSuite() {
    g_support_interp = ChezSchemeInterpreter::instance();
  }
  static void TearDownTestSuite() { g_support_interp.reset(); }
};

static uint64_t address(const void* p) { return reinterpret_cast<uint64_t>(p); }

// --- CrestBox ---------------------------------------------------------------

TEST(CrestBoxTest, AnAddressOfTheRightKindGivesTheValue) {
  CrestBox<int> box(42);
  int* inner = CrestBox<int>::inner(address(&box));
  ASSERT_NE(inner, nullptr);
  EXPECT_EQ(*inner, 42);
  EXPECT_EQ(inner, &box.inner());
}

TEST(CrestBoxTest, ZeroGivesNothing) {
  EXPECT_EQ(CrestBox<int>::inner(0), nullptr);
  EXPECT_EQ(CrestBox<int*>::inner(0), nullptr);
  EXPECT_EQ(as_ref<int>(0), nullptr);
}

TEST(CrestBoxTest, AnotherKindOfBoxGivesNothing) {
  CrestBox<int> box(1);
  CrestBox<std::string> other("not an int");
  EXPECT_EQ(CrestBox<std::string>::inner(address(&box)), nullptr);
  EXPECT_EQ(CrestBox<int>::inner(address(&other)), nullptr);
  // A box of a pointer is not a box of the value.
  EXPECT_EQ(CrestBox<int*>::inner(address(&box)), nullptr);
}

TEST(CrestBoxTest, ABoxOfAPointerGivesThePointer) {
  int value = 7;
  CrestBox<int*> box(&value);
  EXPECT_EQ(CrestBox<int*>::inner(address(&box)), &value);
  EXPECT_EQ(CrestBox<int>::inner(address(&box)), nullptr);
}

TEST(CrestBoxTest, AsRefTakesABoxOfTheValueOrOfAPointerToIt) {
  int value = 9;
  CrestBox<int> owned(value);
  CrestBox<int*> borrowed(&value);
  EXPECT_EQ(as_ref<int>(address(&owned)), &owned.inner());
  EXPECT_EQ(as_ref<int>(address(&borrowed)), &value);
}

// --- CArrayRef: Scheme reads it by offset (scheme/crest/support/array-ref.sls)
// -------------------------

TEST(CArrayRefTest, TheFieldsAreWhereSchemeReadsThem) {
  uintptr_t elements[3] = {10, 20, 30};
  CArrayRef<uintptr_t> ref(elements, 3);
  // The deletor is the first word (the type tag), then the data pointer (offset
  // 8), then the size (offset 16).
  const auto* words = reinterpret_cast<const uintptr_t*>(&ref);
  EXPECT_EQ(words[1], reinterpret_cast<uintptr_t>(elements));
  EXPECT_EQ(words[2], 3u);
}

TEST(CArrayRefTest, ItHasItsOwnTypeTag) {
  uintptr_t elements[1] = {1};
  CArrayRef<uintptr_t> ref(elements, 1);
  EXPECT_NE(AsCrest<CArrayRef<uintptr_t>>::checked(address(&ref)), nullptr);
  EXPECT_EQ(AsCrest<CArrayRef<uint32_t>>::checked(address(&ref)), nullptr);
  CrestBox<int> box(0);
  EXPECT_EQ(AsCrest<CArrayRef<uintptr_t>>::checked(address(&box)), nullptr);
}

// --- scheme_error -----------------------------------------------------------

TEST_F(SupportTest, SchemeErrorIsASymbolAndAString) {
  ptr error = scheme_error("mlir::Block::getArgument", "block pointer is null");
  ASSERT_TRUE(Spairp(error));
  ASSERT_TRUE(Ssymbolp(Scar(error)));
  ASSERT_TRUE(Sstringp(Scdr(error)));
  EXPECT_EQ(convert_to_cpp<std::string>(Ssymbol_to_string(Scar(error))),
            "mlir::Block::getArgument");
  EXPECT_EQ(convert_to_cpp<std::string>(Scdr(error)), "block pointer is null");
}

TEST_F(SupportTest, SchemeErrorTakesATwine) {
  ptr error = scheme_error("who", llvm::Twine("index ") + llvm::Twine(7));
  EXPECT_EQ(convert_to_cpp<std::string>(Scdr(error)), "index 7");
}

// --- register_builder_binding ----------------------------------------------

static bool foreignEntry(const std::string& name) {
  ptr result = scheme_call("foreign-entry?", scheme_string(name));
  return result != Sfalse;
}

TEST_F(SupportTest, ABuilderBindingIsRegisteredOncePerKindOfShell) {
  register_builder_binding(
      "crest::test::support::plain",
      [](mlir::OpBuilder&, uint64_t) -> ptr { return Svoid; });
  EXPECT_TRUE(foreignEntry("crest::test::support::plain<OpBuilder>"));
  EXPECT_TRUE(foreignEntry("crest::test::support::plain<RewriterBase*>"));
  EXPECT_TRUE(foreignEntry("crest::test::support::plain<OpBuilder*>"));
  EXPECT_FALSE(foreignEntry("crest::test::support::plain"));
}

TEST_F(SupportTest,
       ABuilderBindingWhoseNameHasTemplateArgumentsGetsTheKindLast) {
  register_builder_binding("crest::test::support::create<OperationState>",
                           [](mlir::OpBuilder&) -> ptr { return Svoid; });
  EXPECT_TRUE(
      foreignEntry("crest::test::support::create<OperationState,OpBuilder>"));
  EXPECT_TRUE(foreignEntry(
      "crest::test::support::create<OperationState,RewriterBase*>"));
  EXPECT_TRUE(
      foreignEntry("crest::test::support::create<OperationState,OpBuilder*>"));
}
