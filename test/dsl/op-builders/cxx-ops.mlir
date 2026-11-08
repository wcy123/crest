// An op of a C++ dialect can be created without `-> type` when it implements InferTypeOpInterface, as
// in C++, where builder.create<arith::AddFOp>(loc, lhs, rhs) takes the type from its operands:
// arith.addi and arith.mulf get i64 and f64 from theirs.
//
// RUN: %scheme-mlir %S/cxx-ops.sls | FileCheck %s

// CHECK: %[[A:.*]] = arith.constant 2 : i64
// CHECK: %[[B:.*]] = arith.constant 1.500000e+00 : f64
// CHECK: arith.addi %[[A]], %[[A]] : i64
// CHECK: arith.mulf %[[B]], %[[B]] : f64
