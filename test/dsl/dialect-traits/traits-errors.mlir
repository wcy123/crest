// :traits takes a list of names; anything else is reported when the library compiles, on any LLVM.
//
// RUN: not env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/traits-err \
// RUN:   %crest-opt %s --crest-pass="dialects-in-scheme=badtest=passes/bad-not-a-list passes=passes/identity" 2>&1 \
// RUN:   | %FileCheck %s

// CHECK: :traits expects a list of trait names

module {}
