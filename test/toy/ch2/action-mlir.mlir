// Ch2 emits generic MLIR: dialect not yet registered with a custom printer,
// so ops print in generic "string" form with attributes after the body.
// RUN: %scheme-mlir %samples/toy/ch2/toyc.sls %S/example.toy --emit=mlir \
// RUN:   | %FileCheck %s

// CHECK:      module {
// CHECK-NEXT:   "toy.func"() ({
// CHECK-NEXT:   ^bb0(%arg0: tensor<*xf64>, %arg1: tensor<*xf64>):
// CHECK-NEXT:     %0 = "toy.transpose"(%arg1) : (tensor<*xf64>) -> tensor<*xf64>
// CHECK-NEXT:     %1 = "toy.transpose"(%arg0) : (tensor<*xf64>) -> tensor<*xf64>
// CHECK-NEXT:     %2 = "toy.mul"(%1, %0) : (tensor<*xf64>, tensor<*xf64>) -> tensor<*xf64>
// CHECK-NEXT:     "toy.return"(%2) : (tensor<*xf64>) -> ()
// CHECK-NEXT:   }) {function_type = (tensor<*xf64>, tensor<*xf64>) -> (), sym_name = "multiply_transpose"} : () -> ()
// CHECK-NEXT:   "toy.func"() ({
// CHECK-NEXT:     %0 = "toy.constant"() {value = dense<{{.*}}> : tensor<2x3xf64>} : () -> tensor<2x3xf64>
// CHECK-NEXT:     %1 = "toy.constant"() {value = dense<[1.000000e+00, 2.000000e+00, 3.000000e+00, 4.000000e+00, 5.000000e+00, 6.000000e+00]> : tensor<6xf64>} : () -> tensor<6xf64>
// CHECK-NEXT:     %2 = "toy.reshape"(%1) : (tensor<6xf64>) -> tensor<2x3xf64>
// CHECK-NEXT:     %3 = "toy.generic_call"(%0, %2) {callee = "multiply_transpose"} : (tensor<2x3xf64>, tensor<2x3xf64>) -> tensor<*xf64>
// CHECK-NEXT:     %4 = "toy.generic_call"(%2, %0) {callee = "multiply_transpose"} : (tensor<2x3xf64>, tensor<2x3xf64>) -> tensor<*xf64>
// CHECK-NEXT:     %5 = "toy.generic_call"(%3, %4) {callee = "multiply_transpose"} : (tensor<*xf64>, tensor<*xf64>) -> tensor<*xf64>
// CHECK-NEXT:     %6 = "toy.generic_call"(%0, %3) {callee = "multiply_transpose"} : (tensor<2x3xf64>, tensor<*xf64>) -> tensor<*xf64>
// CHECK-NEXT:     "toy.return"() : () -> ()
// CHECK-NEXT:   }) {function_type = () -> (), sym_name = "main"} : () -> ()
// CHECK-NEXT: }
