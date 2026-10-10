// Tests that CREST_DEBUG_MATCH=1 reports :check-where failures with file:line:col.
// The pattern has a :where guard (getNumResults == 99) that always fails.

// RUN: env CREST_DEBUG_MATCH=1 CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt -allow-unregistered-dialect \
// RUN:   --crest-pass="module=passes/debug-match-check-where" %s 2>&1 \
// RUN:   | %FileCheck %s

// CHECK: [%%pattern] exception:

func.func @check_where(%a: i32, %b: i32) -> i32 {
  %0 = "test.mul"(%a, %b) : (i32, i32) -> i32
  return %0 : i32
}
