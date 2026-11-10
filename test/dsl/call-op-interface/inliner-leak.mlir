// The C functions of the dialect-level inliner interface are made once, when the library of the dialect
// is loaded, and shared by every context that loads the dialect, not one more for each.
//
// REQUIRES: llvm-23
// RUN: env CREST_PATH=%S %scheme-mlir %S/inliner-leak-driver.sls %s | %FileCheck %s

// CHECK: shared
