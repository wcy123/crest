// A pass manager owns the passes that it is given (as in C++, where addPass takes a unique_ptr). The same pass
// added twice has two owners and is freed twice. The second add is an error that says so; two different
// passes are fine.
//
// RUN: %scheme-mlir %S/pass-twice.sls root 2>&1 | %FileCheck %s --check-prefix=ROOT
// RUN: %scheme-mlir %S/pass-twice.sls nested 2>&1 | %FileCheck %s --check-prefix=NESTED
// RUN: %scheme-mlir %S/pass-twice.sls two-passes 2>&1 | %FileCheck %s --check-prefix=TWO

// ROOT: mlir::PassManager::addPass: the pass is already in this pass manager
// NESTED: mlir::OpPassManager::addPass: the pass is already in this pass manager
// TWO: no error

module {}
