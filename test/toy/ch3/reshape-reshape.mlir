// reshape(reshape(x)) is reshape(x), with the type of the outer one (ReshapeReshapeOpt). The input of
// the reshapes is the argument of a function, so no constant is folded, and the types differ, so no
// reshape is redundant: no other rule can do this. The C++ tests have no such program.
//
// RUN: %scheme-mlir %samples/toy/ch3/toyc.sls %S/reshape_reshape.toy --emit=mlir | FileCheck %s --check-prefix=RAW
// RUN: %scheme-mlir %samples/toy/ch3/toyc.sls %S/reshape_reshape.toy --emit=mlir --opt | FileCheck %s --check-prefix=OPT

// RAW-LABEL: toy.func @reshape_reshape(%arg0: tensor<*xf64>) -> tensor<*xf64> {
// RAW-NEXT:    %[[R0:[a-zA-Z0-9_]+]] = toy.reshape(%arg0 : tensor<*xf64>) to tensor<2x3xf64>
// RAW-NEXT:    %[[R1:[a-zA-Z0-9_]+]] = toy.reshape(%[[R0]] : tensor<2x3xf64>) to tensor<3x2xf64>
// RAW-NEXT:    toy.return %[[R1]] : tensor<3x2xf64>

// OPT-LABEL: toy.func @reshape_reshape(%arg0: tensor<*xf64>) -> tensor<*xf64> {
// OPT-NEXT:    %[[R:[a-zA-Z0-9_]+]] = toy.reshape(%arg0 : tensor<*xf64>) to tensor<3x2xf64>
// OPT-NEXT:    toy.return %[[R]] : tensor<3x2xf64>
// OPT-NEXT:  }
