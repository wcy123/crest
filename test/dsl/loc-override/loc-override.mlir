// Regression test: :loc expr overrides the auto-derived source location.
//
// Without :loc, begin-mlir-code stamps each emitted op with a FileLineColLoc
// derived from the Scheme source position of the op-name token (i.e. pointing
// at loc-override.sls).  With `:loc my-loc`, the op must instead carry the
// runtime-constructed location — here loc("fake-source.toy":42:1).
//
// This guards against regressions to the bare `:loc expr` parser path
// (commit 5b1db6b5: "use bare :loc token in mlir-gen.sls").

// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt -allow-unregistered-dialect \
// RUN:   --crest-pass="passes=passes/loc-override" \
// RUN:   --mlir-print-debuginfo %s 2>&1 \
// RUN:   | %FileCheck %s

// CHECK-LABEL: func.func @add_i32
// CHECK:         "test.sub"(%arg0, %arg1) : (i32, i32) -> i32 loc([[LOC:#loc[0-9]+]])
// CHECK:       [[LOC]] = loc("fake-source.toy":42:1)
// CHECK-NOT:   loc-override.sls

func.func @add_i32(%arg0: i32, %arg1: i32) -> i32 {
  %0 = "test.add"(%arg0, %arg1) : (i32, i32) -> i32
  return %0 : i32
}
