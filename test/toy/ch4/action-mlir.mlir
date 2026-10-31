// Ch4 before optimization: multiply_transpose is marked private; main uses
// generic_call ops (not yet inlined).
// RUN: %scheme-mlir %samples/toy/ch4/toyc.sls %S/example.toy --emit=mlir \
// RUN:   | %FileCheck %s

// CHECK:      module {
// CHECK-NEXT:   toy.func private @multiply_transpose(%arg0: tensor<*xf64>, %arg1: tensor<*xf64>) {
// CHECK-NEXT:     %0 = toy.transpose(%arg1 : tensor<*xf64>) to tensor<*xf64>
// CHECK-NEXT:     %1 = toy.transpose(%arg0 : tensor<*xf64>) to tensor<*xf64>
// CHECK-NEXT:     %2 = toy.mul %1, %0 : tensor<*xf64>
// CHECK-NEXT:     toy.return %2 : tensor<*xf64>
// CHECK-NEXT:   }
// CHECK-NEXT:   toy.func @main() {
// CHECK-NEXT:     %0 = toy.constant dense<{{.*}}> : tensor<2x3xf64>
// CHECK-NEXT:     %1 = toy.constant dense<[1.000000e+00, 2.000000e+00, 3.000000e+00, 4.000000e+00, 5.000000e+00, 6.000000e+00]> : tensor<6xf64>
// CHECK-NEXT:     %2 = toy.reshape(%1 : tensor<6xf64>) to tensor<2x3xf64>
// CHECK-NEXT:     %3 = toy.generic_call @multiply_transpose(%0, %2) : (tensor<2x3xf64>, tensor<2x3xf64>) -> tensor<*xf64>
// CHECK-NEXT:     %4 = toy.generic_call @multiply_transpose(%2, %0) : (tensor<2x3xf64>, tensor<2x3xf64>) -> tensor<*xf64>
// CHECK-NEXT:     %5 = toy.generic_call @multiply_transpose(%3, %4) : (tensor<*xf64>, tensor<*xf64>) -> tensor<*xf64>
// CHECK-NEXT:     %6 = toy.generic_call @multiply_transpose(%0, %3) : (tensor<2x3xf64>, tensor<*xf64>) -> tensor<*xf64>
// CHECK-NEXT:     toy.return
// CHECK-NEXT:   }
// CHECK-NEXT: }
