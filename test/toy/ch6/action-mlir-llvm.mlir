// RUN: %scheme-mlir %samples/toy/ch6/toyc.sls %S/example.toy --emit=mlir-llvm \
// RUN:   | %FileCheck %s

// CHECK: llvm.func @main
// CHECK: llvm.call @malloc
// CHECK: llvm.store
// CHECK: llvm.br
// CHECK: llvm.call @free
// CHECK: llvm.return
