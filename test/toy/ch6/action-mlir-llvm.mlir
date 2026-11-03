// RUN: %scheme-mlir %samples/toy/ch6/toyc.sls %S/example.toy --emit=mlir-llvm --opt \
// RUN:   | FileCheck %s

// CHECK-LABEL: module {
// CHECK:         llvm.func @free(!llvm.ptr)
// CHECK-NEXT:    llvm.func @malloc(i64) -> !llvm.ptr
// CHECK-NEXT:    llvm.func @main() {
// CHECK:           llvm.call @malloc
// CHECK:           llvm.insertvalue
// CHECK:           llvm.br
// CHECK:           llvm.call @free
// CHECK:           llvm.return
// CHECK:         }
// CHECK-NEXT:  }
