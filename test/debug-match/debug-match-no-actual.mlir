// CREST_DEBUG_MATCH=1 — FAILED: without actual: (branch 4)
//
// Pattern expects test.sub's operand to come from test.add.
// The IR passes a block argument (%x has no defining op) → :set-current-op
// returns #f. FAILED: is logged with the check expression but no actual:
// because the op slot is unbound when :set-current-op fails.

// RUN: env CREST_DEBUG_MATCH=1 CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt -allow-unregistered-dialect \
// RUN:   --crest-pass="module=passes/debug-match-no-actual" %s 2>&1 \
// RUN:   | %FileCheck %s

// FAILED: is logged — no actual: line follows
// CHECK: {{\[%%chain-no-actual\]}} FAILED:
// CHECK-NOT: actual:

func.func @no_chain(%x: i32) -> i32 {
  %0 = "test.sub"(%x) : (i32) -> i32
  return %0 : i32
}
