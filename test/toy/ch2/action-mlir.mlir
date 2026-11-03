// RUN: %scheme-mlir %samples/toy/ch2/toyc.sls %S/example.toy --emit=mlir \
// RUN:   | FileCheck %s

// CHECK-LABEL: module {
// CHECK-NEXT:    "toy.func"() ({
// CHECK-NEXT:    ^bb0(%arg0: tensor<*xf64>, %arg1: tensor<*xf64>):
// CHECK-NEXT:      {{%.*}} = "toy.transpose"(%arg1) : (tensor<*xf64>) -> tensor<*xf64>
// CHECK-NEXT:      {{%.*}} = "toy.transpose"(%arg0) : (tensor<*xf64>) -> tensor<*xf64>
// CHECK-NEXT:      {{%.*}} = "toy.mul"({{%.*}}, {{%.*}}) : (tensor<*xf64>, tensor<*xf64>) -> tensor<*xf64>
// CHECK-NEXT:      "toy.return"({{%.*}}) : (tensor<*xf64>) -> ()
// CHECK-NEXT:    }) {function_type = (tensor<*xf64>, tensor<*xf64>) -> (), sym_name = "multiply_transpose"} : () -> ()
// CHECK-NEXT:    "toy.func"() ({
// CHECK:           "toy.return"() : () -> ()
// CHECK-NEXT:    }) {function_type = () -> (), sym_name = "main"} : () -> ()
// CHECK-NEXT:  }
