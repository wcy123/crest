// The C functions of an op's InferTypeOpInterface are made once and shared by every context that
// loads the dialect, not one more for each.
//
// RUN: env CREST_PATH=%S %scheme-mlir %S/infer-leak-driver.sls %s | %FileCheck %s

// CHECK: shared
