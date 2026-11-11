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

#include "../../lib/Bindings/Support/SchemeWrapper.h"
#include "../../lib/Crest/Dialect.h"
#include "../../lib/Interpreter/ChezSchemeInterpreter.h"
#include "llvm/Config/llvm-config.h"
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
#include <string>
#include <vector>

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

// The side-effect interfaces answer what the op says: the keywords of the
// clauses say "no effects" and "speculatable"; the trait pure says the same and
// a clause of the op replaces the answer that the trait gave. Traits need
// LLVM 23, so the dialect with the trait is used only there.
TEST_F(InterfaceTest, TheSideEffectInterfacesAnswerWhatTheOpSays) {
  mlir::DialectRegistry registry = makeRegistry();
#if LLVM_VERSION_MAJOR >= 23
  auto [typeId, factory] = dialectFactory("ifacepure", "passes/ifacepure");
  registry.insert(typeId, "ifacepure", factory);
#endif
  mlir::MLIRContext ctx(registry, mlir::MLIRContext::Threading::DISABLED);
  mlir::Location loc = mlir::UnknownLoc::get(&ctx);
  auto answers = [&](const char* dialect, const char* opName) {
    ctx.getOrLoadDialect(dialect);
    mlir::OperationState state(loc, opName);
    mlir::Operation* op = mlir::Operation::create(state);
    std::pair<bool, bool> result{mlir::isMemoryEffectFree(op),
                                 mlir::isSpeculatable(op)};
    op->destroy();
    return result;
  };
  EXPECT_EQ(answers("ifacemap", "ifacemap.effect"),
            (std::pair<bool, bool>{true, true}));
#if LLVM_VERSION_MAJOR >= 23
  EXPECT_EQ(answers("ifacepure", "ifacepure.pure-op"),
            (std::pair<bool, bool>{true, true}));
  EXPECT_EQ(answers("ifacepure", "ifacepure.not-speculatable"),
            (std::pair<bool, bool>{true, false}));
#endif
}

// An interface that extends others has the pointers to their Concepts in its
// own Concept (implSymbolOpInterface, ...), which MLIR's code follows to call a
// method of a base through the interface that extends it. InterfaceMap sets
// them when it inserts the model (initializeInterfaceConcept), so each is the
// Concept that the map has for the base.
TEST_F(InterfaceTest, TheConceptOfAnInterfaceHasThePointersToItsBases) {
  mlir::MLIRContext ctx(makeRegistry(), mlir::MLIRContext::Threading::DISABLED);
  mlir::RegisteredOperationName func = name(ctx, "ifacemap.func");
  auto* function = func.getInterface<mlir::FunctionOpInterface>();
  auto* symbol = func.getInterface<mlir::SymbolOpInterface>();
  auto* attrs = func.getInterface<mlir::ArgAndResultAttrsOpInterface>();
  auto* callable = func.getInterface<mlir::CallableOpInterface>();
  ASSERT_NE(function, nullptr);
  ASSERT_NE(symbol, nullptr);
  ASSERT_NE(attrs, nullptr);
  ASSERT_NE(callable, nullptr);
  EXPECT_EQ(function->implSymbolOpInterface, symbol);
  EXPECT_EQ(function->implArgAndResultAttrsOpInterface, attrs);
  EXPECT_EQ(function->implCallableOpInterface, callable);
  EXPECT_EQ(callable->implArgAndResultAttrsOpInterface, attrs);

  mlir::RegisteredOperationName call = name(ctx, "ifacemap.call");
  auto* callOp = call.getInterface<mlir::CallOpInterface>();
  ASSERT_NE(callOp, nullptr);
  EXPECT_EQ(callOp->implArgAndResultAttrsOpInterface,
            call.getInterface<mlir::ArgAndResultAttrsOpInterface>());
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

//===----------------------------------------------------------------------===//
// The prototype of a slot
//
// A slot of a Concept is a C function pointer that MLIR calls, and Scheme fills
// it with a foreign-callable (crest-slot-callable in
// scheme/crest/callback.sls). C++ passes and returns some types by value in a
// way that depends on the platform: a class of one pointer (Type, TypeAttr,
// StringAttr, ...) goes through a pointer on Windows x64, and a TypeRange or an
// OperandRange is two words in registers or a pointer to a copy. Each test
// makes the callable with the kinds that the macro takes, calls it through a
// function pointer of the exact type of the slot, and checks what arrived: it
// is the test that tells, on every platform, that a kind of slot can be
// implemented in Scheme.
//===----------------------------------------------------------------------===//

namespace {

class SlotAbiTest : public InterfaceTest {
protected:
  static void SetUpTestSuite() {
    InterfaceTest::SetUpTestSuite();
    EXPECT_TRUE(g_interp->eval("(import (crest callback))"));
    EXPECT_TRUE(g_interp->eval("(define slot-seen 0)"));
  }

  static ptr evalScheme(const std::string& code) {
    ptr port = scheme_call("open-string-input-port", Sstring(code.c_str()));
    ptr expr = scheme_call("read", port);
    return scheme_call("eval", expr);
  }

  // The entry point of the callable that crest-slot-callable makes.
  template <typename Fn> static Fn slot(const std::string& call) {
    return reinterpret_cast<Fn>(Sunsigned64_value(evalScheme(call)));
  }

  static std::vector<uint64_t> numbers(ptr list) {
    std::vector<uint64_t> result;
    for (; Spairp(list); list = Scdr(list)) {
      result.push_back(Sunsigned64_value(Scar(list)));
    }
    return result;
  }

  static uint64_t address(const void* pointer) {
    return reinterpret_cast<uint64_t>(pointer);
  }

  static mlir::Operation* op(uint64_t fake) {
    return reinterpret_cast<mlir::Operation*>(fake);
  }
};

} // namespace

// A class of one pointer answered by value: Type, as getFunctionType does.
TEST_F(SlotAbiTest, ObjectResult) {
  using Slot = mlir::Type (*)(const void*, mlir::Operation*);
  auto f =
      slot<Slot>("(crest-slot-callable (uptr) object (lambda (op) (+ op 8)))");
  mlir::Type type = f(nullptr, op(0x1000));
  EXPECT_EQ(address(type.getAsOpaquePointer()), 0x1008u);
}

// The same for a PointerUnion, as getCallableForCallee does.
TEST_F(SlotAbiTest, UnionResult) {
  using Slot = mlir::CallInterfaceCallable (*)(const void*, mlir::Operation*);
  auto f =
      slot<Slot>("(crest-slot-callable (uptr) object (lambda (op) (+ op 16)))");
  mlir::CallInterfaceCallable callable = f(nullptr, op(0x2000));
  EXPECT_EQ(address(callable.getOpaqueValue()), 0x2010u);
}

// A class of one pointer taken by value: TypeAttr, as setFunctionTypeAttr does.
TEST_F(SlotAbiTest, ObjectArgument) {
  using Slot = void (*)(const void*, mlir::Operation*, mlir::TypeAttr);
  auto f = slot<Slot>("(crest-slot-callable (uptr object) void (lambda (op "
                      "attr) (set! slot-seen (list op attr))))");
  mlir::MLIRContext ctx;
  mlir::TypeAttr attr = mlir::TypeAttr::get(mlir::IntegerType::get(&ctx, 32));
  f(nullptr, op(0x3000), attr);
  std::vector<uint64_t> seen = numbers(evalScheme("slot-seen"));
  ASSERT_EQ(seen.size(), 2u);
  EXPECT_EQ(seen[0], 0x3000u);
  EXPECT_EQ(seen[1], address(attr.getAsOpaquePointer()));
}

// A PointerUnion taken by value, as setCalleeFromCallable takes it.
TEST_F(SlotAbiTest, UnionArgument) {
  using Slot =
      void (*)(const void*, mlir::Operation*, mlir::CallInterfaceCallable);
  auto f = slot<Slot>("(crest-slot-callable (uptr object) void (lambda (op "
                      "callee) (set! slot-seen (list op callee))))");
  mlir::MLIRContext ctx;
  mlir::SymbolRefAttr ref = mlir::SymbolRefAttr::get(&ctx, "callee");
  f(nullptr, op(0x3000), mlir::CallInterfaceCallable(ref));
  std::vector<uint64_t> seen = numbers(evalScheme("slot-seen"));
  ASSERT_EQ(seen.size(), 2u);
  EXPECT_EQ(seen[0], 0x3000u);
  EXPECT_EQ(seen[1],
            address(mlir::CallInterfaceCallable(ref).getOpaqueValue()));
}

// Two TypeRanges by value, as cloneTypeWith takes: the procedure sees the lists
// of the types, whatever the first word of the range is.
TEST_F(SlotAbiTest, TypeRangeArguments) {
  using Slot = mlir::Type (*)(const void*, mlir::Operation*, mlir::TypeRange,
                              mlir::TypeRange);
  auto f = slot<Slot>("(crest-slot-callable (uptr type-range type-range) object"
                      "  (lambda (op inputs results) (set! slot-seen (list "
                      "inputs results)) 0))");
  mlir::MLIRContext ctx;
  mlir::Type i32 = mlir::IntegerType::get(&ctx, 32);
  mlir::Type f32 = mlir::Float32Type::get(&ctx);
  mlir::Type i64 = mlir::IntegerType::get(&ctx, 64);
  llvm::SmallVector<mlir::Type> inputs{i32, f32};
  llvm::SmallVector<mlir::Type> results{i64};
  f(nullptr, op(0x4000), mlir::TypeRange(inputs), mlir::TypeRange(results));
  ptr seen = evalScheme("slot-seen");
  ASSERT_TRUE(Spairp(seen));
  EXPECT_EQ(numbers(Scar(seen)),
            (std::vector<uint64_t>{address(i32.getAsOpaquePointer()),
                                   address(f32.getAsOpaquePointer())}));
  EXPECT_EQ(numbers(Scar(Scdr(seen))),
            (std::vector<uint64_t>{address(i64.getAsOpaquePointer())}));
}

// An ArrayRef answered by value, as getArgumentTypes does.
TEST_F(SlotAbiTest, ArrayRefResult) {
  using Slot = llvm::ArrayRef<mlir::Type> (*)(const void*, mlir::Operation*);
  mlir::MLIRContext ctx;
  static mlir::Type types[2];
  types[0] = mlir::IntegerType::get(&ctx, 8);
  types[1] = mlir::Float64Type::get(&ctx);
  auto f = slot<Slot>("(crest-slot-callable (uptr) range (lambda (op) (cons " +
                      std::to_string(address(types)) + " 2)))");
  llvm::ArrayRef<mlir::Type> answer = f(nullptr, op(0x5000));
  ASSERT_EQ(answer.size(), 2u);
  EXPECT_EQ(answer.data(), types);
}

// An OperandRange answered by value, as getArgOperands does.
TEST_F(SlotAbiTest, OperandRangeResult) {
  using Slot = mlir::OperandRange (*)(const void*, mlir::Operation*);
  auto f = slot<Slot>(
      "(crest-slot-callable (uptr) range (lambda (op) (cons #x6000 3)))");
  mlir::OperandRange range = f(nullptr, op(0x5000));
  EXPECT_EQ(range.size(), 3u);
  EXPECT_EQ(address(range.getBase()), 0x6000u);
}

// A bool and an enum, as isPrivate and getVisibility answer.
TEST_F(SlotAbiTest, BoolAndEnumResults) {
  using BoolSlot = bool (*)(const void*, mlir::Operation*);
  auto yes =
      slot<BoolSlot>("(crest-slot-callable (uptr) unsigned-8 (lambda (op) 1))");
  auto no =
      slot<BoolSlot>("(crest-slot-callable (uptr) unsigned-8 (lambda (op) 0))");
  EXPECT_TRUE(yes(nullptr, op(0x1000)));
  EXPECT_FALSE(no(nullptr, op(0x1000)));

  using VisibilitySlot =
      mlir::SymbolTable::Visibility (*)(const void*, mlir::Operation*);
  auto visibility =
      slot<VisibilitySlot>("(crest-slot-callable (uptr) int (lambda (op) 2))");
  EXPECT_EQ(visibility(nullptr, op(0x1000)),
            mlir::SymbolTable::Visibility::Nested);
}

// A LogicalResult answered by value, as verifyBody and verifyType do: one byte.
TEST_F(SlotAbiTest, LogicalResultResult) {
  using Slot = llvm::LogicalResult (*)(const void*, mlir::Operation*);
  auto ok =
      slot<Slot>("(crest-slot-callable (uptr) logical-result (lambda (op) 1))");
  auto bad =
      slot<Slot>("(crest-slot-callable (uptr) logical-result (lambda (op) 0))");
  EXPECT_TRUE(mlir::succeeded(ok(nullptr, op(0x1000))));
  EXPECT_TRUE(mlir::failed(bad(nullptr, op(0x1000))));
}

// An enum taken by value and a pointer taken by reference, as setVisibility and
// getEffects take them.
TEST_F(SlotAbiTest, EnumAndReferenceArguments) {
  using Slot =
      void (*)(const void*, mlir::Operation*, mlir::SymbolTable::Visibility,
               llvm::SmallVectorImpl<int>&);
  auto f = slot<Slot>("(crest-slot-callable (uptr int uptr) void"
                      "  (lambda (op visibility sink) (set! slot-seen (list op "
                      "visibility sink))))");
  llvm::SmallVector<int> sink;
  f(nullptr, op(0x7000), mlir::SymbolTable::Visibility::Private, sink);
  std::vector<uint64_t> seen = numbers(evalScheme("slot-seen"));
  ASSERT_EQ(seen.size(), 3u);
  EXPECT_EQ(seen[0], 0x7000u);
  EXPECT_EQ(seen[1],
            static_cast<uint64_t>(mlir::SymbolTable::Visibility::Private));
  EXPECT_EQ(seen[2], address(&sink));
}
