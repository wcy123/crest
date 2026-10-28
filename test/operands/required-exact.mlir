// Positive: 2-required operand pattern matches 2-operand op exactly.

// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt -allow-unregistered-dialect \
// RUN:   --crest-pass="passes=passes/required-exact" %s \
// RUN:   | %FileCheck %s

// CHECK: "test.fused"(%arg0, %arg1) : (i32, i32) -> i32

func.func @exact(%a: i32, %b: i32) -> i32 {
  %0 = "test.add"(%a, %b) : (i32, i32) -> i32
  return %0 : i32
}
