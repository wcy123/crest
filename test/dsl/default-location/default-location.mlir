// An op emitted by begin-mlir-code is stamped with a FileLineColLoc that points at the
// Scheme source line of its op-form, in the lowering file. For a lowering of user code
// the emitted op should carry the user's location, the location of the op it replaces,
// as a C++ lowering does with op->getLoc(). Here test.in is at loc("user.toy":7:3), so
// test.out should be too. See plans/05-g5 (G5); which fix to take is decision D2.
//
// Remove XFAIL when G5 is implemented. If the fix is opt-in (:default-loc), add it to
// the pass first.
//
// XFAIL: *
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt -allow-unregistered-dialect --mlir-print-debuginfo \
// RUN:   --crest-pass="passes=passes/default-location" %s 2>&1 \
// RUN:   | %FileCheck %s

// CHECK-LABEL: func.func @f
// CHECK:         "test.out"(%arg0) : (i32) -> i32 loc([[LOC:#loc[0-9]+]])
// CHECK:       [[LOC]] = loc("user.toy":7:3)
// CHECK-NOT:   default-location.sls

func.func @f(%a: i32) -> i32 {
  %0 = "test.in"(%a) : (i32) -> i32 loc("user.toy":7:3)
  return %0 : i32
}
