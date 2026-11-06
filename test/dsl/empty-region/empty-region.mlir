// A (:region) modifier with no blocks reserves an empty region slot. Before the fix, a region
// with no blocks expanded to a `let` with an empty body and the pass library did not compile.
// The slots keep their order: test.dst gets three regions, empty, one block, empty.
//
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt -allow-unregistered-dialect \
// RUN:   --crest-pass="passes=passes/empty-region" %s | %FileCheck %s

// CHECK-LABEL: func.func @f
// CHECK:         "test.dst"() ({
// CHECK-NEXT:    }, {
// CHECK-NEXT:      "test.one"() : () -> ()
// CHECK-NEXT:    }, {
// CHECK-NEXT:    }) : () -> ()
// CHECK-NOT:     test.src

func.func @f() {
  "test.src"() : () -> ()
  return
}
