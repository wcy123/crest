// :traits takes a list of names; anything else is reported when the library compiles, on any LLVM.
//
// RUN: not env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/traits-err \
// RUN:   %crest-opt %s --crest-pass="passes=passes/bad-not-a-list" 2>&1 \
// RUN:   | %FileCheck %s

// CHECK: error: Failed to import Scheme library: passes/bad-not-a-list: Exception in define-op: :traits expects a list of trait names

module {}
