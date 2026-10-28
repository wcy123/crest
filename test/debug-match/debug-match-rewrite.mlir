// Successful rewrite — verify emitted ops carry loc from the pattern source.
//
// When begin-mlir-code emits an op, it attaches mlir::FileLineColLoc derived
// from the syntax annotation of the op name in the pattern .sls file.
// --mlir-print-debuginfo must show loc(...debug-match-rewrite.sls:...) on the
// rewritten op — not the input file's location.

// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt -allow-unregistered-dialect \
// RUN:   --crest-pass="passes=passes/debug-match-rewrite" \
// RUN:   --mlir-print-debuginfo %s 2>&1 \
// RUN:   | %FileCheck %s

// CHECK: "test.sub"(%arg0, %arg1) : (i32, i32) -> i32 loc([[LOC:#loc[0-9]+]])
// CHECK: [[LOC]] = loc({{.*}}debug-match-rewrite.sls":{{[0-9]+}}:{{[0-9]+}})

func.func @rewrite(%a: i32, %b: i32) -> i32 {
  %0 = "test.add"(%a, %b) : (i32, i32) -> i32
  return %0 : i32
}
