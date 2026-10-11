// CREST_DEBUG_MATCH=1 — match failure diagnostic for non-root op mismatch
//
// When a pattern does not match, CREST_DEBUG_MATCH=1 prints the exact
// Scheme check expression that returned #f, with file:line:col pointing
// to the failing op in the pattern source.
//
// The framework dispatches on the root op (test.sub — correctly registered).
// The pattern also expects the input of test.sub to be produced by test.add,
// but the IR has test.mul — the intermediate :check-op fails.
//
// Expected output: warning with file:line:col, pattern name, FAILED:,
// and "test.add" (the op that was expected but not found).
// The rewrite does NOT fire: test.sub remains unchanged in the output.

// RUN: env CREST_DEBUG_MATCH=1 CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt -allow-unregistered-dialect \
// RUN:   --crest-pass="module=passes/debug-match-check-op" --mlir-print-debuginfo %s 2>&1 \
// RUN:   | %FileCheck %s

// CHECK: [warning]
// CHECK-SAME: debug-match-check-op.sls:{{[0-9]+}}:{{[0-9]+}}:
// CHECK-SAME: [%%expect-test.add-then-sub] FAILED:
// CHECK-SAME: "test.add"
// CHECK: [warning]   actual: test.mul
// CHECK: "test.sub"

func.func @no_match(%a: i32, %b: i32, %c: i32) -> i32 {
  %0 = "test.mul"(%a, %b) : (i32, i32) -> i32
  %1 = "test.sub"(%0, %c) : (i32, i32) -> i32
  return %1 : i32
}
