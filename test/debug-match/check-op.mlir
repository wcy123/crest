// Tests that CREST_DEBUG_MATCH=1 reports :check-op failures with file:line:col.
// The pattern expects "test.add" but the IR has "test.sub" — op name mismatch.

// RUN: env CREST_DEBUG_MATCH=1 CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt -allow-unregistered-dialect \
// RUN:   --crest-pass="module=passes/debug-match-check-op" %s 2>&1 \
// RUN:   | %FileCheck %s

// CHECK: debug-match-check-op.sls
// CHECK-SAME: FAILED:
// CHECK-SAME: "test.add"

func.func @check_op(%a: i32, %b: i32) -> i32 {
  %0 = "test.sub"(%a, %b) : (i32, i32) -> i32
  return %0 : i32
}
