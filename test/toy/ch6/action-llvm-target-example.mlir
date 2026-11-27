// --emit=llvm sets up the target triple and data layout of the host, as C++ toyc does
// (ExecutionEngine::setupTargetTripleAndDataLayout), and --opt runs LLVM's optimizing pipeline (O3)
// over the module (makeOptimizingTransformer); without --opt the module is left as it is (O0).
//
// RUN: %scheme-mlir %samples/toy/ch6/toyc.sls %S/example.toy --emit=llvm 2>&1 | FileCheck %s --check-prefix=O0
// RUN: %scheme-mlir %samples/toy/ch6/toyc.sls %S/example.toy --emit=llvm --opt 2>&1 | FileCheck %s --check-prefix=O3

// O0: target datalayout = "{{.*}}"
// O0: target triple = "{{.*}}"
// O0: define void @main()
// O0: call ptr @malloc

// O3: target datalayout = "{{.*}}"
// O3: target triple = "{{.*}}"
// O3: define void @main()
// O3-NOT: call ptr @malloc
