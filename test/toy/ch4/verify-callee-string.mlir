// The callee of toy.generic_call is a FlatSymbolRefAttr (`@f`), as in C++ Ops.td; a string is not a symbol.
//
// RUN: not %scheme-mlir %S/../toy-ir.sls toy/ch4/toy %s verify 2>&1 | FileCheck %s

// CHECK: must be #t

%0 = toy.constant dense<[1.000000e+00, 2.000000e+00]> : tensor<2xf64>
%1 = "toy.generic_call"(%0) {callee = "f"} : (tensor<2xf64>) -> tensor<*xf64>
