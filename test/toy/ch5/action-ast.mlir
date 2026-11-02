// RUN: %scheme-mlir %samples/toy/ch5/toyc.sls %S/example.toy --emit=ast \
// RUN:   | %FileCheck %s

// CHECK: Module:
// CHECK:   Function
// CHECK:     Proto 'multiply_transpose'
// CHECK:     Params: [a, b]
// CHECK:   Function
// CHECK:     Proto 'main'
