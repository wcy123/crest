// CREST_DEBUG_MATCH=1 — match failure diagnostic for non-root op mismatch
//
// The framework dispatches on the root op (test.sub — correctly registered).
// The pattern also expects the input of test.sub to be produced by test.add,
// but the IR has test.mul — the intermediate :check-op fails.

// RUN: env CREST_DEBUG_MATCH=1 CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt -allow-unregistered-dialect \
// RUN:   --crest-pass="module=passes/debug-match-check-op" --mlir-print-debuginfo %s 2>&1 \
// RUN:   | %FileCheck %s

// FAILED: line — warning from the debug-match system
// CHECK: debug-match-check-op.sls:{{[0-9]+}}:{{[0-9]+}}: {{\[%%expect-test.add-then-sub\]}} FAILED: (and (string=? (mlir-operation-name (vector-ref all-operations 0)) "test.add") (= (mlir-operation-num-results (vector-ref all-operations 0)) 1))
// actual: line — mlir::Operation::print uses inline loc("path":line:col)
// CHECK: actual: %0 = "test.mul"(%arg0, %arg1) : (i32, i32) -> i32 loc(
// CHECK-SAME: debug-match-failed.mlir
// rewrite did NOT fire — test.sub unchanged in module output
// CHECK: "test.sub"(%0, %arg2)

func.func @no_match(%a: i32, %b: i32, %c: i32) -> i32 {
  %0 = "test.mul"(%a, %b) : (i32, i32) -> i32
  %1 = "test.sub"(%0, %c) : (i32, i32) -> i32
  return %1 : i32
}
