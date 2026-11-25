// transpose(transpose(x)) is x (SimplifyRedundantTranspose), as in the C++ test
// mlir/test/Examples/Toy/Ch3/transpose_transpose.toy. The reshape that MLIRGen writes for
// `var a<2, 3>` has the type of its input and is removed too (RedundantReshape).
//
// RUN: %scheme-mlir %samples/toy/ch3/toyc.sls %samples/toy/ch3/transpose_transpose.toy --emit=mlir | FileCheck %s --check-prefix=RAW
// RUN: %scheme-mlir %samples/toy/ch3/toyc.sls %samples/toy/ch3/transpose_transpose.toy --emit=mlir --opt | FileCheck %s --check-prefix=OPT

// RAW-LABEL: toy.func @transpose_transpose(%arg0: tensor<*xf64>) -> tensor<*xf64> {
// RAW-NEXT:    %[[T0:[a-zA-Z0-9_]+]] = toy.transpose(%arg0 : tensor<*xf64>) to tensor<*xf64>
// RAW-NEXT:    %[[T1:[a-zA-Z0-9_]+]] = toy.transpose(%[[T0]] : tensor<*xf64>) to tensor<*xf64>
// RAW-NEXT:    toy.return %[[T1]] : tensor<*xf64>
// RAW:       toy.func @main() {
// RAW-NEXT:    %[[C:[a-zA-Z0-9_]+]] = toy.constant dense<{{.*}}> : tensor<2x3xf64>
// RAW-NEXT:    %[[R:[a-zA-Z0-9_]+]] = toy.reshape(%[[C]] : tensor<2x3xf64>) to tensor<2x3xf64>

// OPT-LABEL: toy.func @transpose_transpose(%arg0: tensor<*xf64>) -> tensor<*xf64> {
// OPT-NEXT:    toy.return %arg0 : tensor<*xf64>
// OPT-NEXT:  }
// OPT-LABEL: toy.func @main() {
// OPT-NEXT:    %[[C:[a-zA-Z0-9_]+]] = toy.constant dense<{{.*}}> : tensor<2x3xf64>
// OPT-NEXT:    %[[CALL:[a-zA-Z0-9_]+]] = toy.generic_call @transpose_transpose(%[[C]]) : (tensor<2x3xf64>) -> tensor<*xf64>
// OPT-NEXT:    toy.print %[[CALL]] : tensor<*xf64>
// OPT-NEXT:    toy.return
// OPT-NOT:   toy.transpose
// OPT-NOT:   toy.reshape
