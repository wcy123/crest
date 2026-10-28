// Variadic operand at end — non-empty (size 2).
// operandSegmentSizes = [1, 2]: one required, two variadic.
// Pattern matches and rewrites to test.fused(%a).

// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt -allow-unregistered-dialect \
// RUN:   --crest-pass="passes=passes/variadic-present" %s \
// RUN:   | %FileCheck %s

// CHECK: "test.fused"(%arg0) : (i32) -> i32

func.func @var_present(%a: i32, %b1: i32, %b2: i32) -> i32 {
  %0 = "test.add"(%a, %b1, %b2) {operandSegmentSizes = array<i32: 1, 2>}
       : (i32, i32, i32) -> i32
  return %0 : i32
}
