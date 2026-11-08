// Toy's constant, add, mul and transpose work out their result types when they are created without
// `-> type`, as the builders of ConstantOp, AddOp, MulOp and TransposeOp do in C++ Toy: the constant
// takes the type of its value, the others an unranked f64 tensor (shape inference refines it later).
//
// REQUIRES: llvm-23
// XFAIL: *
// RUN: %scheme-mlir %S/infer-result-types.sls toy/ch2/toy | FileCheck %s
// RUN: %scheme-mlir %S/infer-result-types.sls toy/ch3/toy | FileCheck %s
// RUN: %scheme-mlir %S/infer-result-types.sls toy/ch4/toy | FileCheck %s
// RUN: %scheme-mlir %S/infer-result-types.sls toy/ch5/toy | FileCheck %s
// RUN: %scheme-mlir %S/infer-result-types.sls toy/ch6/toy | FileCheck %s
// RUN: %scheme-mlir %S/infer-result-types.sls toy/ch7/toy | FileCheck %s

// CHECK: %[[C:.*]] = toy.constant {{.*}} : tensor<2x1xf64>
// CHECK: toy.add %[[C]], %[[C]] : (tensor<2x1xf64>, tensor<2x1xf64>) -> tensor<*xf64>
// CHECK: toy.mul %[[C]], %[[C]] : (tensor<2x1xf64>, tensor<2x1xf64>) -> tensor<*xf64>
// CHECK: toy.transpose(%[[C]] : tensor<2x1xf64>) to tensor<*xf64>
