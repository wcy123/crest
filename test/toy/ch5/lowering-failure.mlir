// A lowering that fails must fail toyc (C++ toyc returns 4 when the pass manager fails), not print a
// half-lowered module and exit 0. toy.generic_call @missing has no callee to inline and no lowering.
//
// RUN: not %scheme-mlir %samples/toy/ch5/toyc.sls %s --emit=mlir-affine 2>&1 | FileCheck %s

// CHECK: failed to legalize operation 'toy.generic_call'

toy.func @main() {
  %0 = toy.constant dense<[1.000000e+00, 2.000000e+00]> : tensor<2xf64>
  %1 = toy.generic_call @missing(%0) : (tensor<2xf64>) -> tensor<*xf64>
  toy.print %1 : tensor<*xf64>
  toy.return
}
