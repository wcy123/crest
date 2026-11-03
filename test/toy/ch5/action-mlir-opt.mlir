// RUN: %scheme-mlir %samples/toy/ch5/toyc.sls %S/example.toy --emit=mlir --opt \
// RUN:   | FileCheck %s

// CHECK-LABEL: module {
// CHECK-NEXT:    toy.func @main() {
// CHECK:           toy.constant dense<{{[[]}}[1.000000e+00, 2.000000e+00, 3.000000e+00], [4.000000e+00, 5.000000e+00, 6.000000e+00]{{[]]}}> : tensor<2x3xf64>
// CHECK:           toy.transpose
// CHECK:           toy.mul
// CHECK:           toy.return
// CHECK-NEXT:    }
// CHECK-NEXT:  }
