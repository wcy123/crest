// Positive: pattern expects 2 required operands, op has 3.
//
// operation-get-operands uses prefix-match for all-required specs:
// n-spec <= n-ops, so the first n-spec operands are bound and extra
// operands are silently ignored.  Pattern fires.

// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt -allow-unregistered-dialect \
// RUN:   --crest-pass="module=passes/required-too-many" %s \
// RUN:   | %FileCheck %s

// Pattern fires: binds %a=%arg0, %b=%arg1, ignores %arg2.
// CHECK: "test.fused"(%arg0, %arg1) : (i32, i32) -> i32

func.func @too_many(%a: i32, %b: i32, %c: i32) -> i32 {
  %0 = "test.add"(%a, %b, %c) : (i32, i32, i32) -> i32
  return %0 : i32
}
