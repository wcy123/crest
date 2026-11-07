// A lowering that fails must fail toyc (C++ toyc returns 4 when the pass manager fails), not print a
// half-lowered module and exit 0. toy.reshape of a non-constant has no lowering in Ch6, and shape
// inference succeeds on this input (a call to a missing function would fail it first, as in C++).
//
// RUN: not %scheme-mlir %samples/toy/ch6/toyc.sls %s --emit=mlir-affine 2>&1 | FileCheck %s

// CHECK: failed to legalize operation 'toy.reshape'

toy.func @main() {
  %0 = toy.constant dense<[[1.000000e+00, 2.000000e+00, 3.000000e+00], [4.000000e+00, 5.000000e+00, 6.000000e+00]]> : tensor<2x3xf64>
  %1 = toy.transpose(%0 : tensor<2x3xf64>) to tensor<3x2xf64>
  %2 = toy.reshape(%1 : tensor<3x2xf64>) to tensor<6xf64>
  toy.print %2 : tensor<6xf64>
  toy.return
}
