// parseModule takes structs and functions in any order, and mlir-gen declares the structs before it
// generates the functions: here `first` uses `Pair` before the declaration of `Pair`.
//
// RUN: %scheme-mlir %samples/toy/ch7/toyc.sls %S/struct-order.toy --emit=jit \
// RUN:   | FileCheck %s

// CHECK: 1.000000 2.000000{{ *$}}
