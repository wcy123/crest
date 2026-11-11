// A dialect says what its callable ops are: the region, the argument types and the result types
// come from the clauses of CallableOpInterface, not from an attribute that CREST would assume.

// RUN: rm -rf %t/callable-methods-scheme && mkdir -p %t/callable-methods-scheme
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/callable-methods-scheme \
// RUN:   %scheme-mlir %S/passes/callable-methods.sls %s \
// RUN:   | %FileCheck %s

// CHECK: one region: 1
// CHECK: one arguments: (i32 f32)
// CHECK: one results: (i64)
// CHECK: two region: 0
// CHECK: two arguments: ()
// CHECK: two results: (f32 f32)

module {
  "callablemethods.one"() ({ }, { }) : () -> ()
  "callablemethods.two"() ({ }, { }) : () -> ()
}
