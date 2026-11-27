// materialize-constant makes a toy.struct_constant when the type is a struct type, and a toy.constant
// otherwise (materialize-constant.mlir). MLIR calls it when a folder returns an attribute, here the
// array attribute of a struct. Shape inference fails on a struct value that is left, so no program that
// toyc runs reaches this case, and the test calls the hook.
//
// RUN: %scheme-mlir %S/../materialize.sls toy/ch7/toy struct-constant | FileCheck %s

// CHECK: toy.struct_constant [dense<[1.000000e+00, 2.000000e+00]> : tensor<2xf64>, dense<[3.000000e+00, 4.000000e+00]> : tensor<2xf64>] : !toy.struct<tensor<2xf64>, tensor<2xf64>>
