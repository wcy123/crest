// The bindings that take a rewriter: func.func and func.return, a block made through the rewriter, the insertion point at
// the end of that block, and the listener of the rewriter (passes/rewriter-creators.sls). None of them was
// named by another test.
//
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/coverage-scheme \
// RUN:   %crest-opt -allow-unregistered-dialect --crest-pass="passes=passes/rewriter-creators" %s \
// RUN:   | %FileCheck %s

// CHECK: the rewriter has a listener: yes
// CHECK: func.func @generated(%{{.*}}: i32) {
// CHECK:   return
// CHECK: }
// CHECK: "test.done"() : () -> i32
// CHECK-NOT: test.trigger

%0 = "test.trigger"() : () -> i32
