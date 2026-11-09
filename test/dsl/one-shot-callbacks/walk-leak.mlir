// The C functions that walk and buildAffineLoopNest make for their callbacks are released when the
// call returns: calling them many times does not leave code objects behind.
//
// RUN: rm -rf %t/walk-leak-scheme && mkdir -p %t/walk-leak-scheme
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/walk-leak-scheme \
// RUN:   %scheme-mlir %S/walk-leak-driver.sls %s | %FileCheck %s

// CHECK: released

module {
}
