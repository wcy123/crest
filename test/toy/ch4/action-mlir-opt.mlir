// Ch4 --opt: inlining + shape inference + canonicalization.
// multiply_transpose is fully inlined; only @main remains with concrete shapes.
// RUN: %scheme-mlir %samples/toy/ch4/toyc.sls %S/example.toy --emit=mlir --opt \
// RUN:   | %FileCheck %s

// CHECK:      module {
// CHECK-NEXT:   toy.func @main() {
// CHECK-NEXT:     %0 = toy.constant dense<{{.*}}> : tensor<2x3xf64>
// CHECK-NEXT:     %1 = toy.constant dense<[1.000000e+00, 2.000000e+00, 3.000000e+00, 4.000000e+00, 5.000000e+00, 6.000000e+00]> : tensor<6xf64>
// CHECK-NEXT:     %2 = toy.constant dense<{{.*}}> : tensor<2x3xf64>
// CHECK-NEXT:     %3 = toy.transpose(%2 : tensor<2x3xf64>) to tensor<3x2xf64>
// CHECK-NEXT:     %4 = toy.transpose(%0 : tensor<2x3xf64>) to tensor<3x2xf64>
// CHECK-NEXT:     %5 = toy.mul %4, %3 : tensor<3x2xf64>
// CHECK-NEXT:     %6 = toy.transpose(%0 : tensor<2x3xf64>) to tensor<3x2xf64>
// CHECK-NEXT:     %7 = toy.transpose(%2 : tensor<2x3xf64>) to tensor<3x2xf64>
// CHECK-NEXT:     %8 = toy.mul %7, %6 : tensor<3x2xf64>
// CHECK-NEXT:     %9 = toy.transpose(%8 : tensor<3x2xf64>) to tensor<2x3xf64>
// CHECK-NEXT:     %10 = toy.transpose(%5 : tensor<3x2xf64>) to tensor<2x3xf64>
// CHECK-NEXT:     %11 = toy.mul %10, %9 : tensor<2x3xf64>
// CHECK-NEXT:     %12 = toy.transpose(%5 : tensor<3x2xf64>) to tensor<2x3xf64>
// CHECK-NEXT:     %13 = toy.transpose(%0 : tensor<2x3xf64>) to tensor<3x2xf64>
// CHECK-NEXT:     %14 = toy.mul %13, %12 : (tensor<3x2xf64>, tensor<2x3xf64>) -> tensor<3x2xf64>
// CHECK-NEXT:     toy.return
// CHECK-NEXT:   }
// CHECK-NEXT: }
