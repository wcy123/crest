// print(c) of the struct example runs through the same lowering as the tensor programs: the 3x2
// array that multiply_transpose returns, one row for each line. The result is the same with and
// without --opt.
//
// RUN: %scheme-mlir %samples/toy/ch7/toyc.sls %S/example.toy --emit=jit \
// RUN:   | FileCheck %s
// RUN: %scheme-mlir %samples/toy/ch7/toyc.sls %S/example.toy --emit=jit --opt \
// RUN:   | FileCheck %s

// CHECK:      1.000000 16.000000{{ *$}}
// CHECK-NEXT: 4.000000 25.000000{{ *$}}
// CHECK-NEXT: 9.000000 36.000000{{ *$}}
