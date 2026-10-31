// RUN: %scheme-mlir %samples/toy/ch1/toyc.sls %S/example.toy --emit=ast \
// RUN:   | %FileCheck %s

// CHECK:        Module:
// CHECK-NEXT:     Function
// CHECK-NEXT:       Proto 'multiply_transpose' @{{.*}}example.toy:0:1
// CHECK-NEXT:       Params: [a, b]
// CHECK-NEXT:       Block {
// CHECK-NEXT:         Return
// CHECK-NEXT:           BinOp: * @{{.*}}example.toy:1:23
// CHECK-NEXT:             Call 'transpose' [ @{{.*}}example.toy:1:10
// CHECK-NEXT:               var: a @{{.*}}example.toy:1:20
// CHECK-NEXT:             ]
// CHECK-NEXT:             Call 'transpose' [ @{{.*}}example.toy:1:25
// CHECK-NEXT:               var: b @{{.*}}example.toy:1:35
// CHECK-NEXT:             ]
// CHECK-NEXT:       } // Block
// CHECK-NEXT:     Function
// CHECK-NEXT:       Proto 'main' @{{.*}}example.toy:4:1
// CHECK-NEXT:       Params: []
// CHECK-NEXT:       Block {
// CHECK-NEXT:         VarDecl a<> @{{.*}}example.toy:5:3
// CHECK-NEXT:           Literal: <2,3>[ <3>[ 1, 2, 3], <3>[ 4, 5, 6]] @{{.*}}example.toy:5:11
// CHECK-NEXT:         VarDecl b<2,3> @{{.*}}example.toy:6:3
// CHECK-NEXT:           Literal: <6>[ 1, 2, 3, 4, 5, 6] @{{.*}}example.toy:6:17
// CHECK-NEXT:         VarDecl c<> @{{.*}}example.toy:7:3
// CHECK-NEXT:           Call 'multiply_transpose' [ @{{.*}}example.toy:7:11
// CHECK-NEXT:             var: a @{{.*}}example.toy:7:30
// CHECK-NEXT:             var: b @{{.*}}example.toy:7:33
// CHECK-NEXT:           ]
// CHECK-NEXT:         VarDecl d<> @{{.*}}example.toy:8:3
// CHECK-NEXT:           Call 'multiply_transpose' [ @{{.*}}example.toy:8:11
// CHECK-NEXT:             var: b @{{.*}}example.toy:8:30
// CHECK-NEXT:             var: a @{{.*}}example.toy:8:33
// CHECK-NEXT:           ]
// CHECK-NEXT:         VarDecl e<> @{{.*}}example.toy:9:3
// CHECK-NEXT:           Call 'multiply_transpose' [ @{{.*}}example.toy:9:11
// CHECK-NEXT:             var: c @{{.*}}example.toy:9:30
// CHECK-NEXT:             var: d @{{.*}}example.toy:9:33
// CHECK-NEXT:           ]
// CHECK-NEXT:         VarDecl f<> @{{.*}}example.toy:10:3
// CHECK-NEXT:           Call 'multiply_transpose' [ @{{.*}}example.toy:10:11
// CHECK-NEXT:             var: a @{{.*}}example.toy:10:30
// CHECK-NEXT:             var: c @{{.*}}example.toy:10:33
// CHECK-NEXT:           ]
// CHECK-NEXT:       } // Block
