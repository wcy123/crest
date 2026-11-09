/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */
//===- InferTypeTest.cpp - InferTypeOpInterface of a Scheme op ------------===//
//
// MLIR calls inferReturnTypes through a function pointer in the Concept in the
// op's interface map, from its own code (a builder, a pass that infers): not
// through crest::callForeign. The pointer is that of a Chez foreign-callable.
// These tests call it as MLIR does.

#include "../../lib/Bindings/Support/XmmGuard.h"
#include "../../lib/Crest/Dialect.h"
#include "../../lib/Interpreter/ChezSchemeInterpreter.h"
#include "mlir/IR/Block.h"
#include "mlir/IR/BuiltinTypes.h"
#include "mlir/IR/DialectRegistry.h"
#include "mlir/IR/MLIRContext.h"
#include "mlir/IR/Operation.h"
#include "mlir/IR/OperationSupport.h"
#include "mlir/Interfaces/InferTypeOpInterface.h"
#include "gtest/gtest.h"
#include <cstdlib>
#if defined(__SSE2__) || defined(_M_X64)
#  include <emmintrin.h>
#endif

using namespace crest;

namespace {

std::shared_ptr<ChezSchemeInterpreter> g_interp;

void setEnv(const char* name, const char* value) {
#ifdef _WIN32
  _putenv_s(name, value);
#else
  setenv(name, value, 1);
#endif
}

// The dialect `bld` of test/dsl/op-builders: bld.add infers the type of its
// left operand; bld.loose adds an isCompatibleReturnTypes that accepts any
// single result type; bld.refined adds a refineReturnTypes that accepts any
// single result type but i64.
class InferTypeTest : public ::testing::Test {
protected:
  static void SetUpTestSuite() {
    setEnv("CREST_PATH", CREST_TEST_DIALECT_DIR);
    setEnv("CREST_SCHEME_BINARY_DIR", CREST_TEST_SCHEME_BINARY_DIR);
    g_interp = ChezSchemeInterpreter::instance(SchemeLogLevel::Warning,
                                               registerMlirForeignFunctions);
  }
  static void TearDownTestSuite() { g_interp.reset(); }

  // A registry with the bld dialect. The context copies it, and with it the
  // factory, whose strings the dialect refers to (its namespace) for as long as
  // the context lives: the factory must not be a temporary of the test.
  static mlir::DialectRegistry makeRegistry() {
    mlir::DialectRegistry registry;
    auto [typeId, factory] = dialectFactory("bld", "passes/bld-dialect");
    registry.insert(typeId, "bld", factory);
    return registry;
  }

  // An op of the bld dialect with i32 operands, created without verifying it.
  // Its methods are called through the function pointers of the Concept in its
  // interface map, as MLIR's code does.
  struct BldOp {
    BldOp(mlir::MLIRContext& ctx, const char* name, unsigned numOperands) {
      ctx.getOrLoadDialect("bld");
      mlir::Type i32 = mlir::IntegerType::get(&ctx, 32);
      mlir::Location loc = mlir::UnknownLoc::get(&ctx);
      for (unsigned i = 0; i < numOperands; ++i) {
        block.addArgument(i32, loc);
      }
      mlir::OperationState state(loc, name);
      state.addOperands(block.getArguments());
      state.addTypes(i32);
      op = mlir::Operation::create(state);
    }
    ~BldOp() { op->destroy(); }

    mlir::InferTypeOpInterface::Concept* getConcept() {
      auto* concept_ = op->getName()
                           .getRegisteredInfo()
                           ->getInterface<mlir::InferTypeOpInterface>();
      EXPECT_NE(concept_, nullptr);
      return concept_;
    }

    // The call that MLIR's code makes, through the function pointer. It is not
    // guarded: Chez's foreign-callable clobbers XMM6 to XMM15 on Windows x64.
    mlir::LogicalResult
    inferUnguarded(llvm::SmallVectorImpl<mlir::Type>& types) {
      return getConcept()->inferReturnTypes(
          op->getContext(), op->getLoc(), op->getOperands(),
          op->getRawDictionaryAttrs(), op->getPropertiesStorage(),
          mlir::RegionRange(op->getRegions()), types);
    }

    // The same, as crest::callForeign calls a callable.
    mlir::LogicalResult infer(llvm::SmallVectorImpl<mlir::Type>& types) {
      return withXmmPreserved([&] { return inferUnguarded(types); });
    }

    // `types` are the result types the op has, and what refining leaves.
    mlir::LogicalResult refine(llvm::SmallVectorImpl<mlir::Type>& types) {
      return withXmmPreserved([&] {
        return getConcept()->refineReturnTypes(
            op->getContext(), op->getLoc(), op->getOperands(),
            op->getRawDictionaryAttrs(), op->getPropertiesStorage(),
            mlir::RegionRange(op->getRegions()), types);
      });
    }

    bool compatible(mlir::TypeRange inferred, mlir::TypeRange actual) {
      return withXmmPreserved([&] {
        return getConcept()->isCompatibleReturnTypes(inferred, actual);
      });
    }

    mlir::Block block;
    mlir::Operation* op = nullptr;
  };
};

} // namespace

TEST_F(InferTypeTest, DirectCallInfersTheTypeOfTheLeftOperand) {
  mlir::MLIRContext ctx(makeRegistry(), mlir::MLIRContext::Threading::DISABLED);
  BldOp add(ctx, "bld.add", 2);
  llvm::SmallVector<mlir::Type, 2> types;
  ASSERT_TRUE(mlir::succeeded(add.infer(types)));
  ASSERT_EQ(types.size(), 1u);
  EXPECT_EQ(types[0], mlir::IntegerType::get(&ctx, 32));
}

// A Scheme op gets the three methods of the interface, from the clauses of its
// :interface2 entry, and the default for a method it has no clause for.
TEST_F(InferTypeTest, CompatibleReturnTypesIsTheClauseOrEquality) {
  mlir::MLIRContext ctx(makeRegistry(), mlir::MLIRContext::Threading::DISABLED);
  mlir::Type i32 = mlir::IntegerType::get(&ctx, 32);
  mlir::Type i64 = mlir::IntegerType::get(&ctx, 64);
  // bld.add has no clause: the types must be equal.
  BldOp add(ctx, "bld.add", 2);
  EXPECT_TRUE(add.compatible({i32}, {i32}));
  EXPECT_FALSE(add.compatible({i32}, {i64}));
  // bld.loose says any single type fits.
  BldOp loose(ctx, "bld.loose", 1);
  EXPECT_TRUE(loose.compatible({i32}, {i64}));
  EXPECT_FALSE(loose.compatible({i32}, {i32, i32}));
}

TEST_F(InferTypeTest, RefineReturnTypesIsTheClauseOrAcceptsAnything) {
  mlir::MLIRContext ctx(makeRegistry(), mlir::MLIRContext::Threading::DISABLED);
  mlir::Type i64 = mlir::IntegerType::get(&ctx, 64);
  mlir::Type f32 = mlir::Float32Type::get(&ctx);
  // bld.add has no clause: the default accepts, and leaves the types.
  BldOp add(ctx, "bld.add", 2);
  llvm::SmallVector<mlir::Type, 2> types = {i64};
  EXPECT_TRUE(mlir::succeeded(add.refine(types)));
  EXPECT_EQ(types.size(), 1u);
  // bld.refined takes any single type but i64, and gets the types it has.
  BldOp refined(ctx, "bld.refined", 1);
  types = {f32};
  EXPECT_TRUE(mlir::succeeded(refined.refine(types)));
  ASSERT_EQ(types.size(), 1u);
  EXPECT_EQ(types[0], f32);
  types = {i64};
  EXPECT_TRUE(mlir::failed(refined.refine(types)));
}

// A second context that loads the dialect gets the interface as well: the
// callables are shared, the Concept is not.
TEST_F(InferTypeTest, EveryContextThatLoadsTheDialectInfers) {
  for (int i = 0; i < 3; ++i) {
    mlir::MLIRContext ctx(makeRegistry(),
                          mlir::MLIRContext::Threading::DISABLED);
    BldOp add(ctx, "bld.add", 2);
    llvm::SmallVector<mlir::Type, 2> types;
    ASSERT_TRUE(mlir::succeeded(add.infer(types))) << "context " << i;
    ASSERT_EQ(types.size(), 1u) << "context " << i;
    EXPECT_EQ(types[0], mlir::IntegerType::get(&ctx, 32)) << "context " << i;
  }
}

#if defined(__SSE2__) || defined(_M_X64)
// REGRESSION (Windows x64): Chez's foreign-callable does not preserve XMM6 to
// XMM15, which that ABI makes callee-saved, and LLVM 23 code keeps a 16-byte
// Block::iterator there across a call. crest::callForeign saves them around
// the calls that C++ makes into a callable, but MLIR's own call through the
// Concept is not one of them. Everywhere else the registers are caller-saved,
// so the test only checks the setup there.
static volatile float g_vector_seed = 1.0f;

TEST_F(InferTypeTest, DirectCallPreservesVectorRegisters) {
  mlir::MLIRContext ctx(makeRegistry(), mlir::MLIRContext::Threading::DISABLED);
  BldOp add(ctx, "bld.add", 2);
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
  llvm::SmallVector<mlir::Type, 2> types;
  EXPECT_TRUE(mlir::succeeded(add.inferUnguarded(types)));
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
