// toy.generic_call is printed as  toy.generic_call @callee(%a) : (tensor<2xf64>) -> tensor<2xf64>
// and must be read back. Its parser failed on every call, with no diagnostic, so a module with a
// call could be printed but not parsed.
//
// RUN: %scheme-mlir %S/../toy-ir.sls toy/ch4/toy %s verify | FileCheck %s

// CHECK: toy.generic_call @callee(%{{.*}}) : (tensor<2xf64>) -> tensor<2xf64>

%0 = toy.constant dense<[1.000000e+00, 2.000000e+00]> : tensor<2xf64>
%1 = toy.generic_call @callee(%0) : (tensor<2xf64>) -> tensor<2xf64>
