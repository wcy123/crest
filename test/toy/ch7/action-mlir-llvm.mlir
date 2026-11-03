// RUN: %scheme-mlir %samples/toy/ch7/toyc.sls %S/example.toy --emit=mlir-llvm --opt \
// RUN:   | FileCheck %s

// CHECK-LABEL: module {
// CHECK:         llvm.func @free(!llvm.ptr)
// CHECK:         llvm.mlir.global private constant @nl
// CHECK:         llvm.mlir.global private constant @frmt_spec
// CHECK:         llvm.func @printf(!llvm.ptr, ...) -> i32
// CHECK:         llvm.func @malloc(i64) -> !llvm.ptr
// CHECK-NEXT:    llvm.func @main() {
// CHECK:           llvm.call @malloc
// CHECK:           llvm.insertvalue
// CHECK:           llvm.call @printf
// CHECK:           llvm.call @free
// CHECK:           llvm.return
// CHECK:         }
// CHECK-NEXT:  }
