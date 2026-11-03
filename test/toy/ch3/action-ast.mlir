// RUN: %scheme-mlir %samples/toy/ch3/toyc.sls %S/example.toy --emit=ast \
// RUN:   | FileCheck %s

// CHECK-LABEL: Module:
// CHECK-NEXT:      Function
// CHECK-NEXT:        Proto 'multiply_transpose' @{{.*}}
// CHECK-NEXT:        Params: [a, b]
// CHECK-NEXT:        Block {
// CHECK-NEXT:          Return
// CHECK-NEXT:            BinOp: * @{{.*}}
// CHECK-NEXT:              Call 'transpose' [ @{{.*}}
// CHECK-NEXT:                var: a @{{.*}}
// CHECK-NEXT:              ]
// CHECK-NEXT:              Call 'transpose' [ @{{.*}}
// CHECK-NEXT:                var: b @{{.*}}
// CHECK-NEXT:              ]
// CHECK-NEXT:        } // Block
// CHECK-NEXT:      Function
// CHECK-NEXT:        Proto 'main' @{{.*}}
// CHECK-NEXT:        Params: []
// CHECK-NEXT:        Block {
// CHECK-NEXT:          VarDecl a<> @{{.*}}
// CHECK-NEXT:            Literal: <2,3>[ <3>[ 1, 2, 3], <3>[ 4, 5, 6]] @{{.*}}
// CHECK-NEXT:          VarDecl b<2,3> @{{.*}}
// CHECK-NEXT:            Literal: <6>[ 1, 2, 3, 4, 5, 6] @{{.*}}
// CHECK-NEXT:          VarDecl c<> @{{.*}}
// CHECK-NEXT:            Call 'multiply_transpose' [ @{{.*}}
// CHECK-NEXT:              var: a @{{.*}}
// CHECK-NEXT:              var: b @{{.*}}
// CHECK-NEXT:            ]
// CHECK-NEXT:          VarDecl d<> @{{.*}}
// CHECK-NEXT:            Call 'multiply_transpose' [ @{{.*}}
// CHECK-NEXT:              var: b @{{.*}}
// CHECK-NEXT:              var: a @{{.*}}
// CHECK-NEXT:            ]
// CHECK-NEXT:          VarDecl e<> @{{.*}}
// CHECK-NEXT:            Call 'multiply_transpose' [ @{{.*}}
// CHECK-NEXT:              var: c @{{.*}}
// CHECK-NEXT:              var: d @{{.*}}
// CHECK-NEXT:            ]
// CHECK-NEXT:          VarDecl f<> @{{.*}}
// CHECK-NEXT:            Call 'multiply_transpose' [ @{{.*}}
// CHECK-NEXT:              var: a @{{.*}}
// CHECK-NEXT:              var: c @{{.*}}
// CHECK-NEXT:            ]
// CHECK-NEXT:        } // Block
