// Ch7 after LLVM dialect lowering: affine/memref lowered to LLVM;
// toy.print stays (dynamically legal); struct types fully erased.
// RUN: %scheme-mlir %samples/toy/ch7/toyc.sls %S/example.toy --emit=mlir-llvm \
// RUN:   | %FileCheck %s

// CHECK:      module {
// CHECK:        llvm.func @free(!llvm.ptr)
// CHECK:        llvm.func @malloc(i64) -> !llvm.ptr
// CHECK:        llvm.func @main() {
// CHECK:          llvm.call @malloc
// CHECK:          llvm.return
