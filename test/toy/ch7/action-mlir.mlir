// The Ch7 tool registers the Ch7 dialect, so the struct ops print in their custom syntax.
//
// RUN: %scheme-mlir %samples/toy/ch7/toyc.sls %S/example.toy --emit=mlir \
// RUN:   | FileCheck %s

// CHECK-LABEL: module {
// CHECK-NEXT:    toy.func private @multiply_transpose(%arg0: tuple<tensor<*xf64>, tensor<*xf64>>) -> tensor<*xf64> {
// CHECK-NEXT:      {{%.*}} = toy.struct_access %arg0[1 : i64] : tuple<tensor<*xf64>, tensor<*xf64>> -> tensor<*xf64>
// CHECK-NEXT:      {{%.*}} = toy.transpose({{%.*}} : tensor<*xf64>) to tensor<*xf64>
// CHECK-NEXT:      {{%.*}} = toy.struct_access %arg0[0 : i64] : tuple<tensor<*xf64>, tensor<*xf64>> -> tensor<*xf64>
// CHECK-NEXT:      {{%.*}} = toy.transpose({{%.*}} : tensor<*xf64>) to tensor<*xf64>
// CHECK-NEXT:      {{%.*}} = toy.mul {{%.*}}, {{%.*}} : tensor<*xf64>
// CHECK-NEXT:      toy.return {{%.*}} : tensor<*xf64>
// CHECK-NEXT:    }
// CHECK-NEXT:    toy.func @main() {
// CHECK-NEXT:      {{%.*}} = toy.struct_constant [dense<{{.*}}> : tensor<2x3xf64>, dense<{{.*}}> : tensor<2x3xf64>] : tuple<tensor<*xf64>, tensor<*xf64>>
// CHECK-NEXT:      {{%.*}} = toy.generic_call @multiply_transpose({{%.*}}) : (tuple<tensor<*xf64>, tensor<*xf64>>) -> tensor<*xf64>
// CHECK-NEXT:      toy.print {{%.*}} : tensor<*xf64>
// CHECK-NEXT:      toy.return
// CHECK-NEXT:    }
// CHECK-NEXT:  }
