// Tests that CREST_DEBUG_MATCH=1 reports :check-eq failures with file:line:col.
// The pattern expects both operands of test.mul to be the same SSA value,
// but %a and %b are distinct — DAG diamond check fails.

// RUN: env CREST_DEBUG_MATCH=1 CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt -allow-unregistered-dialect \
// RUN:   --crest-pass="module=passes/debug-match-check-eq" %s 2>&1 \
// RUN:   | %FileCheck %s

// CHECK: debug-match-check-eq.sls
// CHECK-SAME: FAILED:

func.func @check_eq(%a: i32, %b: i32) -> i32 {
  %0 = "test.mul"(%a, %b) : (i32, i32) -> i32
  return %0 : i32
}
