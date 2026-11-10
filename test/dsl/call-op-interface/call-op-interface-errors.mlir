// CallOpInterface takes no method clauses yet: a clause would silently do nothing, so it is an error
// when the library compiles.
//
// RUN: not env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/call-err \
// RUN:   %crest-opt %s --crest-pass="passes=passes/call-override" 2>&1 \
// RUN:   | %FileCheck %s

// CHECK: Failed to import Scheme library: passes/call-override: Exception in :interface2: mlir::CallOpInterface takes no method clauses

module {}
