// RUN: %scheme-mlir %samples/toy/ch3/toyc.sls %S/example.toy --emit=mlir --opt \
// RUN:   | FileCheck %s

// CHECK-LABEL: module {
// CHECK-NEXT:    toy.func @multiply_transpose(%arg0: tensor<*xf64>, %arg1: tensor<*xf64>) {
// CHECK-NEXT:      {{%.*}} = toy.transpose(%arg1 : tensor<*xf64>) to tensor<*xf64>
// CHECK-NEXT:      {{%.*}} = toy.transpose(%arg0 : tensor<*xf64>) to tensor<*xf64>
// CHECK-NEXT:      {{%.*}} = toy.mul {{%.*}}, {{%.*}} : tensor<*xf64>
// CHECK-NEXT:      toy.return {{%.*}} : tensor<*xf64>
// CHECK-NEXT:    }
// CHECK-NEXT:    toy.func @main() {
// CHECK:           toy.constant dense<{{[[]}}[1.000000e+00, 2.000000e+00, 3.000000e+00], [4.000000e+00, 5.000000e+00, 6.000000e+00]{{[]]}}> : tensor<2x3xf64>
// CHECK:           toy.generic_call @multiply_transpose
// CHECK:           toy.return
// CHECK-NEXT:    }
// CHECK-NEXT:  }
