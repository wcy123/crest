// A binding that fails answers an error (who . why) and Scheme raises it after the C++ call has returned
// (CLAUDE.md Rule 20). No error crosses a C function, so nothing is left behind: stock Chez
// keeps about 208 bytes for every error that does, which this test would see as growth of the C++ heap.
// The message is the same as before the change, and a guard catches the error.
//
// REQUIRES: system-linux
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/errors-scheme \
// RUN:   %scheme-mlir %S/driver.sls | %FileCheck %s

// CHECK: message: Exception in mlir::Block::getArgument: block pointer is null
// CHECK: errors-are-values: ok

module {}
