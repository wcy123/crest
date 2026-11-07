// :traits takes a list of names; anything else is reported when the library compiles, on any LLVM.
//
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/traits-err \
// RUN:   not %crest-opt %s --crest-scheme-dialect=badtest=passes/bad-not-a-list 2>&1 \
// RUN:   | %FileCheck %s

// CHECK: :traits expects a list of trait names

"badtest.op"() : () -> ()
