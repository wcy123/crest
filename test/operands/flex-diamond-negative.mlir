// BUG: flex (optional/variadic) path does not emit :check-eq for already-bound
// variables in diamond patterns.
//
// Pattern requires %shared to be the SAME SSA value in both test.add and
// test.sub.  This function provides DIFFERENT values — the pattern should NOT
// match.
//
// Root cause: the has-flex? branch in analyze.sls emits one :bind-operands
// action for ALL operands of an op without checking whether any operand
// variable is already bound from a prior op.  When test.sub is processed,
// %shared is already bound (from test.add), but the flex path re-binds it
// to test.sub's operand 0 without emitting a :check-eq guard.
//
// Expected after fix : pattern does not fire; test.combine is unchanged.
// Current (buggy) behavior: pattern fires and rewrites using %shared2.

// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt -allow-unregistered-dialect \
// RUN:   --crest-pass="module=passes/flex-diamond" %s \
// RUN:   | %FileCheck %s

// CHECK: "test.combine"
// CHECK-NOT: test.fused

func.func @different_shared(%a: i32, %b: i32, %c: i32, %d: i32) -> i32 {
  %shared1 = "test.mul"(%a, %b) : (i32, i32) -> i32
  %shared2 = "test.mul"(%c, %d) : (i32, i32) -> i32
  %left  = "test.add"(%shared1) {operandSegmentSizes = array<i32: 1, 0>} : (i32) -> i32
  %right = "test.sub"(%shared2) {operandSegmentSizes = array<i32: 1, 0>} : (i32) -> i32
  %out   = "test.combine"(%left, %right) : (i32, i32) -> i32
  return %out : i32
}
