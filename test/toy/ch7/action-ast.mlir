// RUN: %scheme-mlir %samples/toy/ch7/toyc.sls %S/example.toy --emit=ast \
// RUN:   | %FileCheck %s

// CHECK:      Module:
// CHECK-NEXT:     Struct: Struct
// CHECK:          Variables: [
// CHECK:            VarDecl a<>
// CHECK:            VarDecl b<>
// CHECK:      Function
// CHECK:        Proto 'multiply_transpose'
// CHECK:        Params: [value]
// CHECK:        Block {
// CHECK:          Return
// CHECK:            BinOp: *
// CHECK:              Call 'transpose'
// CHECK:                BinOp: .
// CHECK:                  var: value
// CHECK:                  var: a
// CHECK:              Call 'transpose'
// CHECK:                BinOp: .
// CHECK:                  var: value
// CHECK:                  var: b
// CHECK:      Function
// CHECK:        Proto 'main'
// CHECK:        Block {
// CHECK:          VarDecl value<Struct>
// CHECK:            Struct Literal:
// CHECK:          VarDecl c<>
// CHECK:            Call 'multiply_transpose'
// CHECK:          Print [
