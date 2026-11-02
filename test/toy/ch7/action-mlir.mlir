// Ch7 before optimization: multiply_transpose takes a struct (tuple) arg;
// struct field access ops are present; struct_constant holds the struct literal.
// RUN: %scheme-mlir %samples/toy/ch7/toyc.sls %S/example.toy --emit=mlir \
// RUN:   | %FileCheck %s

// CHECK:      module {
// CHECK-NEXT:   toy.func private @multiply_transpose(%arg0: tuple<tensor<*xf64>, tensor<*xf64>>) {
// CHECK:          "toy.struct_access"
// CHECK:          toy.transpose
// CHECK:          "toy.struct_access"
// CHECK:          toy.transpose
// CHECK:          toy.mul
// CHECK:          toy.return
// CHECK:      toy.func @main() {
// CHECK:          "toy.struct_constant"
// CHECK-SAME:       value = [dense
// CHECK:          toy.generic_call @multiply_transpose
// CHECK:          toy.print
// CHECK:          toy.return
