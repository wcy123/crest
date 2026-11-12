// The text that translateModuleToLLVMIR answers is copied into a Scheme string and the C++ buffer
// is freed. Translating the same module 2000 times, with and without an optimization level, must not
// grow the C++ heap.
//
// REQUIRES: system-linux
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/llvm-ir-leak \
// RUN:   %scheme-mlir %S/driver.sls %s | %FileCheck %s

// CHECK: llvm-ir-text: ok
// CHECK-NEXT: llvm-ir-leak: ok

module {
  llvm.func @f(%a: i32, %b: i32) -> i32 {
    %c = llvm.add %a, %b : i32
    %d = llvm.mul %c, %c : i32
    llvm.return %d : i32
  }
  llvm.func @g() {
    llvm.return
  }
}
