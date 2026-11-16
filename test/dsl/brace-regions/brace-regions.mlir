// { ... } is one region in a begin-mlir-code op-form. Several braces in a row are several regions,
// a block is made with a ^label (see brace-blocks), and a brace in the body of a block belongs to the op
// written there.
//
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt -allow-unregistered-dialect \
// RUN:   --crest-pass="passes=passes/brace-regions" %s | %FileCheck %s

// CHECK-LABEL: func.func @two
// CHECK:         "test.dst_two"() ({
// CHECK-NEXT:      "test.a"() : () -> ()
// CHECK-NEXT:    }, {
// CHECK-NEXT:      "test.b"() : () -> ()
// CHECK-NEXT:    }) : () -> ()
func.func @two() {
  "test.two"() : () -> ()
  return
}

// CHECK-LABEL: func.func @static
// CHECK:         "test.dst_static"(%arg0) ({
// CHECK-NEXT:    ^bb0(%[[A:.*]]: i32):
// CHECK-NEXT:      "test.yield"(%[[A]]) : (i32) -> ()
// CHECK-NEXT:    }) : (i32) -> i32
func.func @static(%arg0: i32) -> i32 {
  %0 = "test.static"(%arg0) : (i32) -> i32
  return %0 : i32
}

// CHECK-LABEL: func.func @dynamic
// CHECK:         "test.dst_dynamic"(%arg0) ({
// CHECK-NEXT:    ^bb0(%[[B:.*]]: f32):
// CHECK-NEXT:      "test.yield"(%[[B]]) : (f32) -> ()
// CHECK-NEXT:    }) : (f32) -> f32
func.func @dynamic(%arg0: f32) -> f32 {
  %0 = "test.dynamic"(%arg0) : (f32) -> f32
  return %0 : f32
}

// CHECK-LABEL: func.func @nested
// CHECK:         "test.outer"() ({
// CHECK-NEXT:      "test.inner"() ({
// CHECK-NEXT:        "test.leaf"() : () -> ()
// CHECK-NEXT:      }) : () -> ()
// CHECK-NEXT:      "test.after"() : () -> ()
// CHECK-NEXT:    }) : () -> ()
func.func @nested() {
  "test.nested"() : () -> ()
  return
}

// CHECK-LABEL: func.func @empty
// CHECK:         "test.dst_empty"() ({
// CHECK-NEXT:    }, {
// CHECK-NEXT:      "test.one"() : () -> ()
// CHECK-NEXT:    }, {
// CHECK-NEXT:    }) : () -> ()
func.func @empty() {
  "test.empty"() : () -> ()
  return
}

// CHECK-LABEL: func.func @mixed
// CHECK:         "test.dst_mixed"() ({
// CHECK-NEXT:      "test.old"() : () -> ()
// CHECK-NEXT:    }, {
// CHECK-NEXT:      "test.new"() : () -> ()
// CHECK-NEXT:    }, {
// CHECK-NEXT:    }) : () -> ()
func.func @mixed() {
  "test.mixed"() : () -> ()
  return
}
