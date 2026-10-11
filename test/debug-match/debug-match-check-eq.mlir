// CREST_DEBUG_MATCH=1 — :check-eq DAG-diamond failure
//
// Pattern expects both operands of test.mul to be the same SSA value (%shared),
// but %a and %b are distinct block arguments — :check-eq FAILED.
//
// Verifies the stable warning format:
//   [warning] <file>:<line>:<col>: [<pattern>] FAILED: <scheme-expr>
//   [warning]   actual: <mlir-op-text>

// RUN: env CREST_DEBUG_MATCH=1 CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt -allow-unregistered-dialect \
// RUN:   --crest-pass="module=passes/debug-match-check-eq" \
// RUN:   --mlir-print-debuginfo %s 2>&1 \
// RUN:   | %FileCheck %s

// CHECK: [warning]
// CHECK-SAME: debug-match-check-eq.sls:{{[0-9]+}}:{{[0-9]+}}:
// CHECK-SAME: [%%check-eq-same-value] FAILED:
// CHECK-SAME: eqv?
// CHECK: [warning]   actual:
// CHECK-SAME: "test.mul"
// CHECK-SAME: loc(
// CHECK-SAME: debug-match-check-eq.mlir

func.func @check_eq(%a: i32, %b: i32) -> i32 {
  %0 = "test.mul"(%a, %b) : (i32, i32) -> i32
  return %0 : i32
}
