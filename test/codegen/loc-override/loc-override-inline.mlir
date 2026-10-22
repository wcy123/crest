// Regression test: :loc (filename line column) inline triple shorthand.
//
// Exercises the new (:loc (filename line column) . rest) pattern in
// parse-modifiers-flat, which constructs a FileLineColLoc directly from
// literal components without requiring a pre-built mlir::Location in :then-let.

// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt -allow-unregistered-dialect \
// RUN:   --crest-pass="module=passes/loc-override-inline" \
// RUN:   --mlir-print-debuginfo %s 2>&1 \
// RUN:   | %FileCheck %s

// CHECK-LABEL: func.func @add_i32
// CHECK:         "test.sub"(%arg0, %arg1) : (i32, i32) -> i32 loc([[LOC:#loc[0-9]+]])
// CHECK:       [[LOC]] = loc("inline-source.toy":7:3)
// CHECK-NOT:   loc-override-inline.sls

func.func @add_i32(%arg0: i32, %arg1: i32) -> i32 {
  %0 = "test.add"(%arg0, %arg1) : (i32, i32) -> i32
  return %0 : i32
}
