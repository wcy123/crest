// RUN: %scheme-mlir %samples/toy/ch3/toyc.sls %S/transpose_transpose.toy --emit=ast \
// RUN:   | FileCheck %s

// CHECK-LABEL: Module:
// CHECK-NEXT:      Function
// CHECK-NEXT:        Proto 'transpose_transpose' @{{.*}}
// CHECK-NEXT:        Params: [x]
// CHECK-NEXT:        Block {
// CHECK-NEXT:          Return
// CHECK-NEXT:            Call 'transpose' [ @{{.*}}
// CHECK-NEXT:              Call 'transpose' [ @{{.*}}
// CHECK-NEXT:                var: x @{{.*}}
// CHECK-NEXT:              ]
// CHECK-NEXT:            ]
// CHECK-NEXT:        } // Block
// CHECK-NEXT:      Function
// CHECK-NEXT:        Proto 'main' @{{.*}}
// CHECK-NEXT:        Params: []
// CHECK-NEXT:        Block {
// CHECK-NEXT:          VarDecl a<2,3> @{{.*}}
// CHECK-NEXT:            Literal: <2,3>[ <3>[ 1, 2, 3], <3>[ 4, 5, 6]] @{{.*}}
// CHECK-NEXT:          VarDecl b<> @{{.*}}
// CHECK-NEXT:            Call 'transpose_transpose' [ @{{.*}}
// CHECK-NEXT:              var: a @{{.*}}
// CHECK-NEXT:            ]
// CHECK-NEXT:          Print [ @{{.*}}
// CHECK-NEXT:            var: b @{{.*}}
// CHECK-NEXT:          ]
// CHECK-NEXT:        } // Block
