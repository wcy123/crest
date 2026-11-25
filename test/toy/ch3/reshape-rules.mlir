// Each of the four rules of ch3 on an input where no other rule can do the work: the reshapes and
// transposes have a function argument as input, so FoldConstantReshape is not what removes them.
// The C++ tests do not isolate them (mlir/test/Examples/Toy/Ch3).
//
// RUN: %scheme-mlir %samples/toy/ch3/toyc.sls %s --emit=mlir | FileCheck %s --check-prefix=RAW
// RUN: %scheme-mlir %samples/toy/ch3/toyc.sls %s --emit=mlir --opt | FileCheck %s --check-prefix=OPT

// SimplifyRedundantTranspose: transpose(transpose(x)) is x.
toy.func @transposes(%arg0: tensor<2x3xf64>) {
  %0 = toy.transpose(%arg0 : tensor<2x3xf64>) to tensor<3x2xf64>
  %1 = toy.transpose(%0 : tensor<3x2xf64>) to tensor<2x3xf64>
  toy.print %1 : tensor<2x3xf64>
  toy.return
}

// ReshapeReshapeOpt: reshape(reshape(x)) is reshape(x), with the type of the outer one.
toy.func @reshape_reshape(%arg0: tensor<2x3xf64>) {
  %0 = toy.reshape(%arg0 : tensor<2x3xf64>) to tensor<3x2xf64>
  %1 = toy.reshape(%0 : tensor<3x2xf64>) to tensor<6x1xf64>
  toy.print %1 : tensor<6x1xf64>
  toy.return
}

// RedundantReshape: a reshape to the type of its input is its input.
toy.func @redundant_reshape(%arg0: tensor<2x3xf64>) {
  %0 = toy.reshape(%arg0 : tensor<2x3xf64>) to tensor<2x3xf64>
  toy.print %0 : tensor<2x3xf64>
  toy.return
}

// FoldConstantReshape: a reshape of a constant is a constant of the new type.
toy.func @fold_constant_reshape() {
  %0 = toy.constant dense<[1.0, 2.0, 3.0, 4.0, 5.0, 6.0]> : tensor<6xf64>
  %1 = toy.reshape(%0 : tensor<6xf64>) to tensor<2x3xf64>
  toy.print %1 : tensor<2x3xf64>
  toy.return
}

// RAW-LABEL: toy.func @transposes(
// RAW-NEXT:    %[[T0:[a-zA-Z0-9_]+]] = toy.transpose(%arg0 : tensor<2x3xf64>) to tensor<3x2xf64>
// RAW-NEXT:    %[[T1:[a-zA-Z0-9_]+]] = toy.transpose(%[[T0]] : tensor<3x2xf64>) to tensor<2x3xf64>
// RAW-NEXT:    toy.print %[[T1]] : tensor<2x3xf64>
// RAW-LABEL: toy.func @reshape_reshape(
// RAW-NEXT:    %[[R0:[a-zA-Z0-9_]+]] = toy.reshape(%arg0 : tensor<2x3xf64>) to tensor<3x2xf64>
// RAW-NEXT:    %[[R1:[a-zA-Z0-9_]+]] = toy.reshape(%[[R0]] : tensor<3x2xf64>) to tensor<6x1xf64>
// RAW-LABEL: toy.func @redundant_reshape(
// RAW-NEXT:    %[[S:[a-zA-Z0-9_]+]] = toy.reshape(%arg0 : tensor<2x3xf64>) to tensor<2x3xf64>
// RAW-LABEL: toy.func @fold_constant_reshape(
// RAW-NEXT:    %[[C:[a-zA-Z0-9_]+]] = toy.constant dense<[1.000000e+00, 2.000000e+00, 3.000000e+00, 4.000000e+00, 5.000000e+00, 6.000000e+00]> : tensor<6xf64>
// RAW-NEXT:    %[[F:[a-zA-Z0-9_]+]] = toy.reshape(%[[C]] : tensor<6xf64>) to tensor<2x3xf64>

// OPT-LABEL: toy.func @transposes(
// OPT-NEXT:    toy.print %arg0 : tensor<2x3xf64>
// OPT-NEXT:    toy.return
// OPT-LABEL: toy.func @reshape_reshape(
// OPT-NEXT:    %[[R:[a-zA-Z0-9_]+]] = toy.reshape(%arg0 : tensor<2x3xf64>) to tensor<6x1xf64>
// OPT-NEXT:    toy.print %[[R]] : tensor<6x1xf64>
// OPT-NEXT:    toy.return
// OPT-LABEL: toy.func @redundant_reshape(
// OPT-NEXT:    toy.print %arg0 : tensor<2x3xf64>
// OPT-NEXT:    toy.return
// OPT-LABEL: toy.func @fold_constant_reshape(
// OPT-NEXT:    %[[K:[a-zA-Z0-9_]+]] = toy.constant dense<{{[[]}}[1.000000e+00, 2.000000e+00, 3.000000e+00], [4.000000e+00, 5.000000e+00, 6.000000e+00]{{[]]}}> : tensor<2x3xf64>
// OPT-NEXT:    toy.print %[[K]] : tensor<2x3xf64>
// OPT-NEXT:    toy.return
// OPT-NOT:   toy.transpose
