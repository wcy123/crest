// A ^label inside { } starts a block, up to the next ^label or the }. Items before the first
// ^label are an entry block. A ^label inside a nested { } belongs to the nested region.
//
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt -allow-unregistered-dialect \
// RUN:   --crest-pass="passes=passes/brace-blocks" %s | %FileCheck %s

// CHECK-LABEL: func.func @entry
// CHECK:         "test.dst_entry"() ({
// CHECK-NEXT:      "test.a"() : () -> ()
// CHECK-NEXT:      "test.a2"() : () -> ()
// CHECK-NEXT:    ^bb1:{{.*}}
// CHECK-NEXT:      "test.b"() : () -> ()
// CHECK-NEXT:    }) : () -> ()
func.func @entry() {
  "test.entry"() : () -> ()
  return
}

// CHECK-LABEL: func.func @regions
// CHECK:         "test.dst_regions"() ({
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
func.func @regions() {
  "test.regions"() : () -> ()
  return
}

// CHECK-LABEL: func.func @old
// CHECK:         "test.dst_old"() ({
// CHECK-NEXT:      "test.a"() : () -> ()
// CHECK-NEXT:    ^bb1:{{.*}}
// CHECK-NEXT:      "test.b"() : () -> ()
// CHECK-NEXT:    }) : () -> ()
func.func @old() {
  "test.old"() : () -> ()
  return
}
