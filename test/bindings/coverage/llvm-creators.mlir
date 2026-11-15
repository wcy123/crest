// The bindings that make LLVM dialect ops (a function declaration, a global string, its address, a constant and a GEP
// to its first character), and the ones that look a symbol up in the module and read the type of a global, are used by
// llvm-creators.sls. Each of them was named by no other test.
//
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/coverage-scheme \
// RUN:   %scheme-mlir %S/llvm-creators.sls | %FileCheck %s

// CHECK: found the global by name: yes
// CHECK: found the function by name: yes
// CHECK: type of the global is the array: yes
// CHECK: llvm.func @printf(!llvm.ptr, ...) -> i32
// CHECK: llvm.mlir.global private constant @greeting("hello")
// CHECK: %[[ADDRESS:.*]] = llvm.mlir.addressof @greeting : !llvm.ptr
// CHECK: %[[ZERO:.*]] = llvm.mlir.constant(0 : i64) : i64
// CHECK: llvm.getelementptr %[[ADDRESS]][%[[ZERO]], %[[ZERO]]] : (!llvm.ptr, i64, i64) -> !llvm.ptr, !llvm.array<6 x i8>

module {}
