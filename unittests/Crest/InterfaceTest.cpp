/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */
//===- InterfaceTest.cpp - the interfaces of a Scheme op ------------------===//
//
// An op that Scheme defines gets its interfaces from the :interfaces entries of
// define-op: models in the InterfaceMap of its definition, the base interfaces
// among them. The tests ask the map, as MLIR's own code does, and call the
// default methods through the interface.

#include "../../lib/Crest/Dialect.h"
#include "../../lib/Interpreter/ChezSchemeInterpreter.h"
#include "mlir/IR/Builders.h"
#include "mlir/IR/BuiltinAttributes.h"
#include "mlir/IR/BuiltinTypes.h"
#include "mlir/IR/DialectRegistry.h"
#include "mlir/IR/MLIRContext.h"
#include "mlir/IR/Operation.h"
#include "mlir/IR/OperationSupport.h"
#include "mlir/IR/SymbolTable.h"
#include "mlir/Interfaces/CallInterfaces.h"
#include "mlir/Interfaces/FunctionInterfaces.h"
#include "mlir/Interfaces/SideEffectInterfaces.h"
#include "mlir/Transforms/InliningUtils.h"
#include "gtest/gtest.h"
#include <cstdlib>

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

class InterfaceTest : public ::testing::Test {
protected:
  static void SetUpTestSuite() {
    setEnv("CREST_PATH", CREST_TEST_DIALECT_DIR);
    setEnv("CREST_SCHEME_BINARY_DIR", CREST_TEST_SCHEME_BINARY_DIR);
    g_interp = ChezSchemeInterpreter::instance(SchemeLogLevel::Warning,
                                               registerMlirForeignFunctions);
  }
  static void TearDownTestSuite() { g_interp.reset(); }

  // A registry with the ifacemap dialect. The context copies it, and with it
  // the factory, whose strings the dialect refers to for as long as the context
  // lives.
  static mlir::DialectRegistry makeRegistry() {
    mlir::DialectRegistry registry;
    auto [typeId, factory] = dialectFactory("ifacemap", "passes/ifacemap");
    registry.insert(typeId, "ifacemap", factory);
    return registry;
  }

  // The registered name of an op of the dialect, which is loaded.
  static mlir::RegisteredOperationName name(mlir::MLIRContext& ctx,
                                            const char* op) {
    ctx.getOrLoadDialect("ifacemap");
    std::optional<mlir::RegisteredOperationName> info =
        mlir::RegisteredOperationName::lookup(op, &ctx);
    EXPECT_TRUE(info.has_value()) << op;
    return *info;
  }
};

} // namespace

// Each interface is in the map of the op that has it in its :interfaces entry,
// and not in the map of one that has not.
TEST_F(InterfaceTest, TheMapHasTheInterfacesOfTheEntries) {
  mlir::MLIRContext ctx(makeRegistry(), mlir::MLIRContext::Threading::DISABLED);

  auto callee = name(ctx, "ifacemap.callee");
  EXPECT_TRUE(callee.hasInterface<mlir::CallableOpInterface>());
  EXPECT_FALSE(callee.hasInterface<mlir::CallOpInterface>());
  EXPECT_FALSE(callee.hasInterface<mlir::FunctionOpInterface>());

  auto call = name(ctx, "ifacemap.call");
  EXPECT_TRUE(call.hasInterface<mlir::CallOpInterface>());
  EXPECT_FALSE(call.hasInterface<mlir::CallableOpInterface>());

  auto symbol = name(ctx, "ifacemap.symbol");
  EXPECT_TRUE(symbol.hasInterface<mlir::SymbolOpInterface>());
  EXPECT_FALSE(symbol.hasInterface<mlir::FunctionOpInterface>());

  auto effect = name(ctx, "ifacemap.effect");
  EXPECT_TRUE(effect.hasInterface<mlir::MemoryEffectOpInterface>());
  EXPECT_TRUE(effect.hasInterface<mlir::ConditionallySpeculatable>());

  auto bare = name(ctx, "ifacemap.bare");
  EXPECT_FALSE(bare.hasInterface<mlir::FunctionOpInterface>());
  EXPECT_FALSE(bare.hasInterface<mlir::CallableOpInterface>());
  EXPECT_FALSE(bare.hasInterface<mlir::CallOpInterface>());
  EXPECT_FALSE(bare.hasInterface<mlir::SymbolOpInterface>());
  EXPECT_FALSE(bare.hasInterface<mlir::MemoryEffectOpInterface>());
  EXPECT_FALSE(bare.hasInterface<mlir::ConditionallySpeculatable>());
}

// An interface brings the interfaces it extends, and its Concept points at
// them: FunctionOpInterface extends SymbolOpInterface,
// ArgAndResultAttrsOpInterface and CallableOpInterface, and CallableOpInterface
// and CallOpInterface extend ArgAndResultAttrsOpInterface. A registry keyed by
// op name never had them in a map: hasInterface was false for all of these.
TEST_F(InterfaceTest, AnInterfaceBringsTheOnesItExtends) {
  mlir::MLIRContext ctx(makeRegistry(), mlir::MLIRContext::Threading::DISABLED);

  auto func = name(ctx, "ifacemap.func");
  EXPECT_TRUE(func.hasInterface<mlir::FunctionOpInterface>());
  EXPECT_TRUE(func.hasInterface<mlir::SymbolOpInterface>());
  EXPECT_TRUE(func.hasInterface<mlir::ArgAndResultAttrsOpInterface>());
  EXPECT_TRUE(func.hasInterface<mlir::CallableOpInterface>());
  auto* concept_ = func.getInterface<mlir::FunctionOpInterface>();
  ASSERT_NE(concept_, nullptr);
  EXPECT_EQ(concept_->implSymbolOpInterface,
            func.getInterface<mlir::SymbolOpInterface>());
  EXPECT_EQ(concept_->implArgAndResultAttrsOpInterface,
            func.getInterface<mlir::ArgAndResultAttrsOpInterface>());
  EXPECT_EQ(concept_->implCallableOpInterface,
            func.getInterface<mlir::CallableOpInterface>());

  auto callee = name(ctx, "ifacemap.callee");
  EXPECT_TRUE(callee.hasInterface<mlir::ArgAndResultAttrsOpInterface>());
  EXPECT_EQ(callee.getInterface<mlir::CallableOpInterface>()
                ->implArgAndResultAttrsOpInterface,
            callee.getInterface<mlir::ArgAndResultAttrsOpInterface>());

  auto call = name(ctx, "ifacemap.call");
  EXPECT_TRUE(call.hasInterface<mlir::ArgAndResultAttrsOpInterface>());
  EXPECT_EQ(call.getInterface<mlir::CallOpInterface>()
                ->implArgAndResultAttrsOpInterface,
            call.getInterface<mlir::ArgAndResultAttrsOpInterface>());

  // Declared by itself, the base interface is there as well.
  EXPECT_TRUE(name(ctx, "ifacemap.attrs")
                  .hasInterface<mlir::ArgAndResultAttrsOpInterface>());
}

// The interface works on an op of the dialect: the default methods read the
// attributes the way MLIR's func.func does.
TEST_F(InterfaceTest, TheDefaultMethodsWork) {
  mlir::MLIRContext ctx(makeRegistry(), mlir::MLIRContext::Threading::DISABLED);
  name(ctx, "ifacemap.func");
  mlir::Location loc = mlir::UnknownLoc::get(&ctx);
  mlir::Type fnType = mlir::FunctionType::get(&ctx, {}, {});

  mlir::OperationState state(loc, "ifacemap.func");
  state.addAttribute("function_type", mlir::TypeAttr::get(fnType));
  state.addAttribute("sym_name", mlir::StringAttr::get(&ctx, "f"));
  state.addRegion();
  mlir::Operation* op = mlir::Operation::create(state);

  auto fn = mlir::dyn_cast<mlir::FunctionOpInterface>(op);
  ASSERT_TRUE(fn);
  EXPECT_EQ(fn.getFunctionType(), fnType);
  EXPECT_EQ(mlir::cast<mlir::SymbolOpInterface>(op).getName(), "f");
  EXPECT_TRUE(mlir::isa<mlir::CallableOpInterface>(op));
  op->destroy();
}

// The interface is part of the definition of the op, so another context that
// loads the dialect gets its own map with the same interfaces.
TEST_F(InterfaceTest, EveryContextThatLoadsTheDialectHasThem) {
  for (int i = 0; i < 3; ++i) {
    mlir::MLIRContext ctx(makeRegistry(),
                          mlir::MLIRContext::Threading::DISABLED);
    EXPECT_TRUE(
        name(ctx, "ifacemap.func").hasInterface<mlir::FunctionOpInterface>())
        << "context " << i;
  }
}

// The dialect-level :interfaces clause gives the dialect its inliner interface,
// in every context that loads the dialect, and not a dialect that has none.
TEST_F(InterfaceTest, TheDialectHasItsInlinerInterface) {
  for (int i = 0; i < 3; ++i) {
    mlir::MLIRContext ctx(makeRegistry(),
                          mlir::MLIRContext::Threading::DISABLED);
    mlir::Dialect* dialect = ctx.getOrLoadDialect("ifacemap");
    ASSERT_NE(dialect, nullptr);
    EXPECT_NE(dialect->getRegisteredInterface<mlir::DialectInlinerInterface>(),
              nullptr)
        << "context " << i;
  }
}
