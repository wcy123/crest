// The location of an op emitted by begin-mlir-code is deliberate:
//
//   - without :loc it is the Scheme source position of the op-form in the pass file, so
//     a diagnostic on the op resolves to the exact line of the pass that created it;
//   - with an explicit :loc it is that location, here the location of the op replaced.
//
// test.in is rewritten without :loc, test.in2 with `:loc user-loc`.
//
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt -allow-unregistered-dialect --mlir-print-debuginfo \
// RUN:   --crest-pass="passes=passes/default-location" %s 2>&1 \
// RUN:   | %FileCheck %s

// CHECK-LABEL: func.func @f
// CHECK:         "test.out"(%arg0) : (i32) -> i32 loc([[SRC:#loc[0-9]+]])
// CHECK:         "test.out2"(%{{.*}}) : (i32) -> i32 loc([[USER:#loc[0-9]+]])
// CHECK-DAG:   [[SRC]] = loc("{{.*}}default-location.sls":{{[0-9]+}}:{{[0-9]+}})
// CHECK-DAG:   [[USER]] = loc("user.toy":9:5)

func.func @f(%a: i32) -> i32 {
  %0 = "test.in"(%a) : (i32) -> i32 loc("user.toy":7:3)
  %1 = "test.in2"(%0) : (i32) -> i32 loc("user.toy":9:5)
  return %1 : i32
}
