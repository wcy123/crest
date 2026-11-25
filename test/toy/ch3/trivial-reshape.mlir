// Reshapes to the type the value already has are removed (RedundantReshape) and the reshape of a
// constant is folded into the constant (FoldConstantReshape), as in the C++ test
// mlir/test/Examples/Toy/Ch3/trivial_reshape.toy: three reshapes and a flat constant become one constant.
//
// RUN: %scheme-mlir %samples/toy/ch3/toyc.sls %S/trivial_reshape.toy --emit=mlir | FileCheck %s --check-prefix=RAW
// RUN: %scheme-mlir %samples/toy/ch3/toyc.sls %S/trivial_reshape.toy --emit=mlir --opt | FileCheck %s --check-prefix=OPT

// RAW-LABEL: toy.func @main() {
// RAW-NEXT:    %[[C:[a-zA-Z0-9_]+]] = toy.constant dense<[1.000000e+00, 2.000000e+00]> : tensor<2xf64>
// RAW-NEXT:    %[[R1:[a-zA-Z0-9_]+]] = toy.reshape(%[[C]] : tensor<2xf64>) to tensor<2x1xf64>
// RAW-NEXT:    %[[R2:[a-zA-Z0-9_]+]] = toy.reshape(%[[R1]] : tensor<2x1xf64>) to tensor<2x1xf64>
// RAW-NEXT:    %[[R3:[a-zA-Z0-9_]+]] = toy.reshape(%[[R2]] : tensor<2x1xf64>) to tensor<2x1xf64>
// RAW-NEXT:    toy.print %[[R3]] : tensor<2x1xf64>

// OPT-LABEL: toy.func @main() {
// OPT-NEXT:    %[[C:[a-zA-Z0-9_]+]] = toy.constant dense<{{[[]}}[1.000000e+00], [2.000000e+00]{{[]]}}> : tensor<2x1xf64>
// OPT-NEXT:    toy.print %[[C]] : tensor<2x1xf64>
// OPT-NEXT:    toy.return
// OPT-NOT:   toy.reshape
