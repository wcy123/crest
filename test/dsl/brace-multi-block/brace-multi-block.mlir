// A ^label inside { } starts a block, up to the next ^label or the }. Items before the first
// ^label are an entry block. A ^label inside a nested { } belongs to the nested region.
//
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt -allow-unregistered-dialect \
// RUN:   --crest-pass="passes=passes/brace-multi-block" %s | %FileCheck %s

// CHECK-LABEL: func.func @one_region_many_blocks
// CHECK:         "test.dst_one_region_many_blocks"() ({
// CHECK-NEXT:      "test.a"() : () -> ()
// CHECK-NEXT:      "test.a2"() : () -> ()
// CHECK-NEXT:    ^bb1:{{.*}}
// CHECK-NEXT:      "test.b"() : () -> ()
// CHECK-NEXT:    }) : () -> ()
func.func @one_region_many_blocks() {
  "test.one_region_many_blocks"() : () -> ()
  return
}

// CHECK-LABEL: func.func @many_regions_many_blocks
// CHECK:         "test.dst_many_regions_many_blocks"() ({
// CHECK-NEXT:      "test.c"() : () -> ()
// CHECK-NEXT:    ^bb1:{{.*}}
// CHECK-NEXT:      "test.inner"() ({
// CHECK-NEXT:        "test.d"() : () -> ()
// CHECK-NEXT:      ^bb1:{{.*}}
// CHECK-NEXT:        "test.e"() : () -> ()
// CHECK-NEXT:      }) : () -> ()
// CHECK-NEXT:      "test.f"() : () -> ()
// CHECK-NEXT:    }, {
// CHECK-NEXT:      "test.g"() : () -> ()
// CHECK-NEXT:    ^bb1:{{.*}}
// CHECK-NEXT:      "test.h"() : () -> ()
// CHECK-NEXT:    }) : () -> ()
func.func @many_regions_many_blocks() {
  "test.many_regions_many_blocks"() : () -> ()
  return
}
