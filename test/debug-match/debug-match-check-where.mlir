// CREST_DEBUG_MATCH=1 — :check-where guard failure with file:line:col
//
// Pattern matches test.add but :where (eqv? 1 2) always returns #f cleanly.
// CREST_DEBUG_MATCH prints FAILED: with location from the pattern source.
//
// Verifies the stable warning format:
//   [warning] <file>:<line>:<col>: [<pattern>] FAILED: <scheme-expr>
//   [warning]   actual: <mlir-op-text>

// RUN: env CREST_DEBUG_MATCH=1 CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt -allow-unregistered-dialect \
// RUN:   --crest-pass="module=passes/debug-match-check-where" \
// RUN:   --mlir-print-debuginfo %s 2>&1 \
// RUN:   | %FileCheck %s

// CHECK: debug-match-check-where.sls:{{[0-9]+}}:{{[0-9]+}}: {{\[%%where-always-false\]}} FAILED: {{.*}}eqv?
// CHECK: actual: {{.*}}"test.add"{{.*}}loc({{.*}}debug-match-check-where.mlir

func.func @check_where(%a: i32, %b: i32) -> i32 {
  %0 = "test.add"(%a, %b) : (i32, i32) -> i32
  return %0 : i32
}
