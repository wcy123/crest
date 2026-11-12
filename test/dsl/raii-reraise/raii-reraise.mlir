// REGRESSION: with-raii freed its resource twice when an error passed through a guard with no clause for
// it (R6RS re-raises it in the dynamic environment of the original raise, so control re-enters the body and
// leaves it again). For with-OperationState that was a double free of the box: "invalid memory reference".
//
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/raii %scheme-mlir %S/driver.sls | %FileCheck %s

// CHECK: frees: 1
