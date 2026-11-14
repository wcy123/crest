// --emit=jit of a program without main: the engine is made, and the call to main fails. The error of MLIR
// is said (it was dropped, and only "JIT invocation failed" was left), and toyc ends with status 1.
//
// RUN: not %scheme-mlir %samples/toy/ch6/toyc.sls %S/no-main.toy --emit=jit 2>&1 | FileCheck %s

// CHECK: JIT invocation failed: Symbols not found: [ _mlir_main ]
