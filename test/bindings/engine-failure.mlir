// An execution engine that cannot be made is an error that says why (Rule 20), and not the answer 0 that
// Scheme has to remember to test: the reason of MLIR was dropped (consumeError), and the caller could only say
// "failed". The module has an arith op that cannot be lowered to LLVM IR.
//
// RUN: %scheme-mlir %S/engine-failure.sls 2>&1 | %FileCheck %s

// CHECK-NOT: engine:
// CHECK: error: mlir::ExecutionEngine::create: {{.+}}

module {}
