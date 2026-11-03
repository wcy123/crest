// RUN: %scheme-mlir %samples/toy/ch7/toyc.sls %S/example.toy --emit=ast \
// RUN:   | FileCheck %s

// CHECK-LABEL:   Module:
// CHECK-NEXT:     Struct: Struct @{{.*}}
// CHECK-NEXT:       Variables: [
// CHECK-NEXT:         VarDecl a<> @{{.*}}
// CHECK-NEXT:           <unknown expr>
// CHECK-NEXT:         VarDecl b<> @{{.*}}
// CHECK-NEXT:           <unknown expr>
// CHECK-NEXT: ]
// CHECK-NEXT:     Function
// CHECK-NEXT:       Proto 'multiply_transpose' @{{.*}}
// CHECK-NEXT:       Params: [value]
// CHECK-NEXT:       Block {
// CHECK-NEXT:         Return
// CHECK-NEXT:           BinOp: * @{{.*}}
// CHECK-NEXT:             Call 'transpose' [ @{{.*}}
// CHECK-NEXT:               BinOp: . @{{.*}}
// CHECK-NEXT:                 var: value @{{.*}}
// CHECK-NEXT:                 var: a @{{.*}}
// CHECK-NEXT:             ]
// CHECK-NEXT:             Call 'transpose' [ @{{.*}}
// CHECK-NEXT:               BinOp: . @{{.*}}
// CHECK-NEXT:                 var: value @{{.*}}
// CHECK-NEXT:                 var: b @{{.*}}
// CHECK-NEXT:             ]
// CHECK-NEXT:       } // Block
// CHECK-NEXT:     Function
// CHECK-NEXT:       Proto 'main' @{{.*}}
// CHECK-NEXT:       Params: []
// CHECK-NEXT:       Block {
// CHECK-NEXT:         VarDecl value<Struct> @{{.*}}
// CHECK-NEXT:           Struct Literal: @{{.*}}
// CHECK-NEXT:             Literal: <2,3>[ <3>[ 1, 2, 3], <3>[ 4, 5, 6]{{[]]}} @{{.*}}
// CHECK-NEXT:             Literal: <2,3>[ <3>[ 1, 2, 3], <3>[ 4, 5, 6]{{[]]}} @{{.*}}
// CHECK-NEXT:         VarDecl c<> @{{.*}}
// CHECK-NEXT:           Call 'multiply_transpose' [ @{{.*}}
// CHECK-NEXT:             var: value @{{.*}}
// CHECK-NEXT:           ]
// CHECK-NEXT:         Print [ @{{.*}}
// CHECK-NEXT:           var: c @{{.*}}
// CHECK-NEXT:         ]
// CHECK-NEXT:       } // Block
