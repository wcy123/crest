// A { } keeps its place among the other modifiers of an op-form: the region index counts the
// braces and the (:move-region ...) before it, and :loc after a brace still sets the location.
//
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt -allow-unregistered-dialect -mlir-print-debuginfo \
// RUN:   --crest-pass="passes=passes/brace-with-other-modifiers" %s | %FileCheck %s

// CHECK-LABEL: func.func @move_between_braces
// CHECK:         "test.dst_move_between_braces"() ({
// CHECK-NEXT:      "test.first"() : () -> ()
// CHECK-NEXT:    }, {
// CHECK-NEXT:    ^bb0(%[[A:[^:]*]]: i32{{.*}}):
// CHECK-NEXT:      "test.use"(%[[A]]) : (i32) -> ()
// CHECK-NEXT:    }, {
// CHECK-NEXT:      "test.last"() : () -> ()
// CHECK-NEXT:    }) : () -> ()
// CHECK-NOT:     test.move_between_braces
func.func @move_between_braces() {
  "test.move_between_braces"() ({
  ^bb0(%a: i32):
    "test.use"(%a) : (i32) -> ()
  }) : () -> ()
  return
}

// CHECK-LABEL: func.func @loc_after_braces
// CHECK:         "test.dst_loc_after_braces"() ({
// CHECK-NEXT:      "test.inner"() : () -> ()
// CHECK-NEXT:    }, {
// CHECK-NEXT:      "test.second"() : () -> ()
// CHECK-NEXT:    }) : () -> () loc(#[[LOC:loc[0-9]+]])
func.func @loc_after_braces() {
  "test.loc_after_braces"() : () -> ()
  return
}

// The location of the new op is the one written after the braces.
// CHECK: #[[LOC]] = loc("brace-loc.sls":7:3)
