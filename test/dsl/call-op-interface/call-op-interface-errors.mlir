// MLIR has no default for most methods of CallOpInterface (the op class gives them), so an entry that
// misses one is an error when the library compiles.
//
// RUN: not env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/call-err \
// RUN:   %crest-opt %s --crest-pass="passes=passes/call-override" 2>&1 \
// RUN:   | %FileCheck %s

// CHECK: Failed to import Scheme library: passes/call-override: Exception in :interfaces: mlir::CallOpInterface needs a clause for getCallableForCallee

module {}
