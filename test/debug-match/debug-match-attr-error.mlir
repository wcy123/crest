// CREST_DEBUG_MATCH=1 — :attr absence treated as match failure (not exception)
//
// (:attr "missing") checks attribute presence first via hasAttr?.
// When absent it returns #f — a clean match failure, not an exception.
// CREST_DEBUG_MATCH=1 prints FAILED: with file:line:col and actual: op.
//
// Verifies the stable warning format:
//   [warning] <file>:<line>:<col>: [<pattern>] FAILED: <scheme-expr>
//   [warning]   actual: <mlir-op-text>

// RUN: env CREST_DEBUG_MATCH=1 CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt -allow-unregistered-dialect \
// RUN:   --crest-pass="module=passes/debug-match-attr-error" \
// RUN:   --mlir-print-debuginfo %s 2>&1 \
// RUN:   | %FileCheck %s

// CHECK: debug-match-attr-error.sls:{{[0-9]+}}:{{[0-9]+}}: {{\[%%require-missing-attr\]}} :check-where FAILED: (let ((%cur (vector-ref all-operations 0))) (and (mlir-Operation::hasAttr? %cur "missing") (mlir-operation-get-attr %cur "missing")))
// CHECK: "test.add"(%arg0, %arg1) : (i32, i32) -> i32 loc([[LOC:#loc[0-9]+]])
// CHECK: [[LOC]] = loc({{.*}}debug-match-attr-error.mlir":{{[0-9]+}}:{{[0-9]+}})

func.func @attr_error(%a: i32, %b: i32) -> i32 {
  %0 = "test.add"(%a, %b) : (i32, i32) -> i32
  return %0 : i32
}
