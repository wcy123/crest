// A struct with two different fields: toy.struct_access has the index of the field that the program
// names, 0 for first and 1 for second, and the struct_constant has the two tensors in the order of the
// declaration. The tensors differ, so a swapped index changes the result.
//
// RUN: %scheme-mlir %samples/toy/ch7/toyc.sls %S/fields.toy --emit=mlir \
// RUN:   | FileCheck %s

// CHECK-LABEL: module {
// CHECK-NEXT:   toy.func @main() {
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = toy.struct_constant [dense<[1.000000e+00, 2.000000e+00, 3.000000e+00]> : tensor<3xf64>, dense<{{[[]}}[4.000000e+00, 5.000000e+00], [6.000000e+00, 7.000000e+00]{{[]]}}> : tensor<2x2xf64>] : !toy.struct<tensor<*xf64>, tensor<*xf64>>
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = toy.struct_access %{{[a-zA-Z0-9_]+}}[0] : !toy.struct<tensor<*xf64>, tensor<*xf64>> -> tensor<*xf64>
// CHECK-NEXT:     %{{[a-zA-Z0-9_]+}} = toy.struct_access %{{[a-zA-Z0-9_]+}}[1] : !toy.struct<tensor<*xf64>, tensor<*xf64>> -> tensor<*xf64>
// CHECK-NEXT:     toy.print %{{[a-zA-Z0-9_]+}} : tensor<*xf64>
// CHECK-NEXT:     toy.print %{{[a-zA-Z0-9_]+}} : tensor<*xf64>
// CHECK-NEXT:     toy.return
// CHECK-NEXT:   }
// CHECK-NEXT: }
