// Variadic operand at end — empty (size 0).
// operandSegmentSizes = [1, 0]: one required, variadic absent.
// Pattern does NOT match (:where fails on unbound-value? %b); op unchanged.

// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt -allow-unregistered-dialect \
// RUN:   --crest-pass="passes=passes/variadic-present" %s \
// RUN:   | %FileCheck %s

// Pattern does not fire — op is unchanged
// CHECK: "test.add"(%arg0)

func.func @var_absent(%a: i32) -> i32 {
  %0 = "test.add"(%a) {operandSegmentSizes = array<i32: 1, 0>}
       : (i32) -> i32
  return %0 : i32
}
