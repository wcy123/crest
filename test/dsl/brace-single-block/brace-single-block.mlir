// { ... } is one region in a begin-mlir-code op-form. Several braces in a row are several regions,
// a block is made with a ^label (see brace-multi-block), and a brace in the body of a block belongs to the op
// written there.
//
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt -allow-unregistered-dialect \
// RUN:   --crest-pass="passes=passes/brace-single-block" %s | %FileCheck %s

// CHECK-LABEL: func.func @many_regions_one_block
// CHECK:         "test.dst_many_regions_one_block"() ({
// CHECK-NEXT:      "test.a"() : () -> ()
// CHECK-NEXT:    }, {
// CHECK-NEXT:      "test.b"() : () -> ()
// CHECK-NEXT:    }) : () -> ()
func.func @many_regions_one_block() {
  "test.many_regions_one_block"() : () -> ()
  return
}

// CHECK-LABEL: func.func @one_region_static_arguments
// CHECK:         "test.dst_one_region_static_arguments"(%arg0) ({
// CHECK-NEXT:    ^bb0(%[[A:.*]]: i32):
// CHECK-NEXT:      "test.yield"(%[[A]]) : (i32) -> ()
// CHECK-NEXT:    }) : (i32) -> i32
func.func @one_region_static_arguments(%arg0: i32) -> i32 {
  %0 = "test.one_region_static_arguments"(%arg0) : (i32) -> i32
  return %0 : i32
}

// CHECK-LABEL: func.func @one_region_dynamic_arguments
// CHECK:         "test.dst_one_region_dynamic_arguments"(%arg0) ({
// CHECK-NEXT:    ^bb0(%[[B:.*]]: f32):
// CHECK-NEXT:      "test.yield"(%[[B]]) : (f32) -> ()
// CHECK-NEXT:    }) : (f32) -> f32
func.func @one_region_dynamic_arguments(%arg0: f32) -> f32 {
  %0 = "test.one_region_dynamic_arguments"(%arg0) : (f32) -> f32
  return %0 : f32
}

// CHECK-LABEL: func.func @nested_braces
// CHECK:         "test.outer"() ({
// CHECK-NEXT:      "test.inner"() ({
// CHECK-NEXT:        "test.leaf"() : () -> ()
// CHECK-NEXT:      }) : () -> ()
// CHECK-NEXT:      "test.after"() : () -> ()
// CHECK-NEXT:    }) : () -> ()
func.func @nested_braces() {
  "test.nested_braces"() : () -> ()
  return
}

// CHECK-LABEL: func.func @empty_region
// CHECK:         "test.dst_empty_region"() ({
// CHECK-NEXT:    }, {
// CHECK-NEXT:      "test.one"() : () -> ()
// CHECK-NEXT:    }, {
// CHECK-NEXT:    }) : () -> ()
func.func @empty_region() {
  "test.empty_region"() : () -> ()
  return
}

// CHECK-LABEL: func.func @braces_among_attributes
// CHECK:         "test.dst_braces_among_attributes"() ({
// CHECK-NEXT:      "test.one"() : () -> ()
// CHECK-NEXT:    }, {
// CHECK-NEXT:      "test.two"() : () -> ()
// CHECK-NEXT:    }) {first = "a", second = 7 : index} : () -> ()
func.func @braces_among_attributes() {
  "test.braces_among_attributes"() : () -> ()
  return
}
