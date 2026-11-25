// A reshape to the type of its input is its input (RedundantReshape). This cannot be a Toy program:
// in Toy a value with a known shape is a constant (FoldConstantReshape removes the reshape) or the
// result of a reshape (ReshapeReshapeOpt removes it), so another rule always does the work. As MLIR
// text the input is an argument with a known shape, and only RedundantReshape applies.
//
// RUN: %scheme-mlir %samples/toy/ch3/toyc.sls %s --emit=mlir | FileCheck %s --check-prefix=RAW
// RUN: %scheme-mlir %samples/toy/ch3/toyc.sls %s --emit=mlir --opt | FileCheck %s --check-prefix=OPT

toy.func @redundant_reshape(%arg0: tensor<2x3xf64>) {
  %0 = toy.reshape(%arg0 : tensor<2x3xf64>) to tensor<2x3xf64>
  toy.print %0 : tensor<2x3xf64>
  toy.return
}

// RAW-LABEL: toy.func @redundant_reshape(
// RAW-NEXT:    %[[R:[a-zA-Z0-9_]+]] = toy.reshape(%arg0 : tensor<2x3xf64>) to tensor<2x3xf64>
// RAW-NEXT:    toy.print %[[R]] : tensor<2x3xf64>

// OPT-LABEL: toy.func @redundant_reshape(
// OPT-NEXT:    toy.print %arg0 : tensor<2x3xf64>
// OPT-NEXT:    toy.return
// OPT-NOT:   toy.reshape
