// RUN: %scheme-mlir %samples/toy/ch3/toyc.sls %S/trivial_reshape.toy --emit=ast \
// RUN:   | FileCheck %s

// CHECK-LABEL: Module:
// CHECK-NEXT:      Function
// CHECK-NEXT:        Proto 'main' @{{.*}}
// CHECK-NEXT:        Params: []
// CHECK-NEXT:        Block {
// CHECK-NEXT:          VarDecl a<2,1> @{{.*}}
// CHECK-NEXT:            Literal: <2>[ 1, 2] @{{.*}}
// CHECK-NEXT:          VarDecl b<2,1> @{{.*}}
// CHECK-NEXT:            var: a @{{.*}}
// CHECK-NEXT:          VarDecl c<2,1> @{{.*}}
// CHECK-NEXT:            var: b @{{.*}}
// CHECK-NEXT:          Print [ @{{.*}}
// CHECK-NEXT:            var: c @{{.*}}
// CHECK-NEXT:          ]
// CHECK-NEXT:        } // Block
