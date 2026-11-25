// RUN: %scheme-mlir %samples/toy/ch3/toyc.sls %S/reshape_reshape.toy --emit=ast \
// RUN:   | FileCheck %s

// CHECK-LABEL: Module:
// CHECK-NEXT:      Function
// CHECK-NEXT:        Proto 'reshape_reshape' @{{.*}}
// CHECK-NEXT:        Params: [x]
// CHECK-NEXT:        Block {
// CHECK-NEXT:          VarDecl a<2,3> @{{.*}}
// CHECK-NEXT:            var: x @{{.*}}
// CHECK-NEXT:          VarDecl b<3,2> @{{.*}}
// CHECK-NEXT:            var: a @{{.*}}
// CHECK-NEXT:          Return
// CHECK-NEXT:            var: b @{{.*}}
// CHECK-NEXT:        } // Block
// CHECK-NEXT:      Function
// CHECK-NEXT:        Proto 'main' @{{.*}}
// CHECK-NEXT:        Params: []
// CHECK-NEXT:        Block {
// CHECK-NEXT:          VarDecl c<2,3> @{{.*}}
// CHECK-NEXT:            Literal: <2,3>[ <3>[ 1, 2, 3], <3>[ 4, 5, 6]] @{{.*}}
// CHECK-NEXT:          VarDecl d<> @{{.*}}
// CHECK-NEXT:            Call 'reshape_reshape' [ @{{.*}}
// CHECK-NEXT:              var: c @{{.*}}
// CHECK-NEXT:            ]
// CHECK-NEXT:          Print [ @{{.*}}
// CHECK-NEXT:            var: d @{{.*}}
// CHECK-NEXT:          ]
// CHECK-NEXT:        } // Block
