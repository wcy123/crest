// The two fields of the struct are printed one after the other: second (a 2x2 array, two rows), then first
// (a vector, one line with no newline at its end, see print-ranks.toy in ch6).
//
// RUN: %scheme-mlir %samples/toy/ch7/toyc.sls %S/fields.toy --emit=jit \
// RUN:   | FileCheck %s
// RUN: %scheme-mlir %samples/toy/ch7/toyc.sls %S/fields.toy --emit=jit --opt \
// RUN:   | FileCheck %s

// CHECK:      4.000000 5.000000{{ *$}}
// CHECK-NEXT: 6.000000 7.000000{{ *$}}
// CHECK-NEXT: 1.000000 2.000000 3.000000{{ *$}}
