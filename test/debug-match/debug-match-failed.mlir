// CREST_DEBUG_MATCH=1 — match failure diagnostic
//
// When a pattern does not match, CREST_DEBUG_MATCH=1 prints the exact
// Scheme check expression that returned #f, with file:line:col pointing
// to the failing op in the pattern source.
//
// Pattern: expects test.add — IR has test.sub → op name check fails.
// Expected: warning line containing FAILED: and "test.add".

// RUN: env CREST_DEBUG_MATCH=1 CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt -allow-unregistered-dialect \
// RUN:   --crest-pass="module=passes/debug-match-check-op" %s 2>&1 \
// RUN:   | %FileCheck %s

// CHECK: FAILED:
// CHECK-SAME: "test.add"

func.func @no_match(%a: i32, %b: i32) -> i32 {
  %0 = "test.sub"(%a, %b) : (i32, i32) -> i32
  return %0 : i32
}
