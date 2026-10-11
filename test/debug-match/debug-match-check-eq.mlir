// CREST_DEBUG_MATCH=1 — :check-eq DAG-diamond failure
//
// Pattern expects both operands of test.mul to be the same SSA value,
// but %a and %b are distinct — :check-eq FAILED.

// RUN: env CREST_DEBUG_MATCH=1 CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt -allow-unregistered-dialect \
// RUN:   --crest-pass="module=passes/debug-match-check-eq" \
// RUN:   --mlir-print-debuginfo %s 2>&1 \
// RUN:   | %FileCheck %s

// CHECK: debug-match-check-eq.sls:{{[0-9]+}}:{{[0-9]+}}: {{\[%%check-eq-same-value\]}} :check-eq FAILED: (eqv? (mlir-operation-get-operand-value (vector-ref all-operations 0) 1) %shared)
// CHECK: actual: %0 = "test.mul"(%arg0, %arg1) : (i32, i32) -> i32 loc(
// CHECK-SAME: debug-match-check-eq.mlir

func.func @check_eq(%a: i32, %b: i32) -> i32 {
  %0 = "test.mul"(%a, %b) : (i32, i32) -> i32
  return %0 : i32
}
