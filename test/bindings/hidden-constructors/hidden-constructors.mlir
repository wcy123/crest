// A raw constructor answers a heap object that only its with- macro frees, so its public library does not export
// it. The macros still work, because a macro refers to the bindings of its own library.
// (ExecutionEngine::create needs a compiled module, so with-ExecutionEngine is covered by test/toy.)
//
// RUN: %scheme-mlir %S/driver.sls | %FileCheck %s

// CHECK: mlir::MLIRContext::new: hidden
// CHECK: mlir::DialectRegistry::new: hidden
// CHECK: mlir::PassManager::new: hidden
// CHECK: mlir::RewritePatternSet::RewritePatternSet: hidden
// CHECK: mlir::OperationState::create: hidden
// CHECK: mlir::ExecutionEngine::create: hidden
// CHECK: with-PassManager: made
// CHECK: with-RewritePatternSet: made
// CHECK: with-OperationState: made

module {}
