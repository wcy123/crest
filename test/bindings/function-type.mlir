// The input and result types of a FunctionType come back as lists, in order.
//
// RUN: %scheme-mlir %S/function-type.sls | %FileCheck %s

// CHECK: (inputs (i32 f32))
// CHECK: (results (i64))
// CHECK: (empty () ())

module {}
