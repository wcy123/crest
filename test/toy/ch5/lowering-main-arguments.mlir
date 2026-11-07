// FuncOpLowering only lowers `main` with no inputs and no results (LowerToAffineLoops.cpp), so a main
// with an argument stays a toy.func, which is illegal, and the lowering fails.
//
// RUN: not %scheme-mlir %samples/toy/ch5/toyc.sls %s --emit=mlir-affine 2>&1 | FileCheck %s

// CHECK: failed to legalize operation 'toy.func'

toy.func @main(%arg0: tensor<2xf64>) {
  toy.print %arg0 : tensor<2xf64>
  toy.return
}
