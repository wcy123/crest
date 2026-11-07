// mlir-gen reports through the diagnostic engine at the location of the source, as the C++ MLIRGen
// does, and toyc fails with status 1 (a null module) instead of an uncaught Scheme exception.
//
// RUN: not %scheme-mlir %samples/toy/ch4/toyc.sls %S/unknown-variable.toy -emit=mlir 2>&1 | FileCheck %s --check-prefix=UNKNOWN
// RUN: not %scheme-mlir %samples/toy/ch4/toyc.sls %S/transpose-arguments.toy -emit=mlir 2>&1 | FileCheck %s --check-prefix=TRANSPOSE

// UNKNOWN: unknown-variable.toy":2:9): error: error: unknown variable 'b'
// TRANSPOSE: transpose-arguments.toy":2:9): error: MLIR codegen encountered an error: toy.transpose does not accept multiple arguments
