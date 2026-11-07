// As the C++ Ch7 MLIRGen, a call to a function that has not been generated yet is an error at the call,
// reported by mlir-gen (a function enters the table after its body, so a later definition and a recursive
// call are rejected as well). No module is printed and toyc fails with status 1.
//
// RUN: not %scheme-mlir %samples/toy/ch7/toyc.sls %S/undefined-function.toy -emit=mlir 2>&1 | FileCheck %s --check-prefix=MISSING
// RUN: not %scheme-mlir %samples/toy/ch7/toyc.sls %S/forward-call.toy -emit=mlir 2>&1 | FileCheck %s --check-prefix=FORWARD
// RUN: not %scheme-mlir %samples/toy/ch7/toyc.sls %S/recursive-call.toy -emit=mlir 2>&1 | FileCheck %s --check-prefix=RECURSIVE
// RUN: not %scheme-mlir %samples/toy/ch7/toyc.sls %S/undefined-function.toy -emit=mlir -opt 2>&1 | FileCheck %s --check-prefix=MISSING
// RUN: not %scheme-mlir %samples/toy/ch7/toyc.sls %S/undefined-function.toy -emit=mlir 2>/dev/null | FileCheck %s --check-prefix=STDOUT --allow-empty

// MISSING: undefined-function.toy":1:11): error: no defined function found for 'missing'
// MISSING-NOT: toy.generic_call
// MISSING-NOT: Shape inference
// FORWARD: forward-call.toy":1:11): error: no defined function found for 'twice'
// RECURSIVE: recursive-call.toy":1:10): error: no defined function found for 'loop'
// STDOUT-NOT: toy
