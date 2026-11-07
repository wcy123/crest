// Mistakes in the names of :traits are reported when the dialect loads (the table of names is C++).
//
// REQUIRES: llvm-23
// RUN: not env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/traits-err-unknown \
// RUN:   %crest-opt %s --crest-pass="dialects-in-scheme=badtest=passes/bad-unknown passes=passes/identity" 2>&1 \
// RUN:   | %FileCheck %s --check-prefix=UNKNOWN
// RUN: not env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/traits-err-repeated \
// RUN:   %crest-opt %s --crest-pass="dialects-in-scheme=badtest=passes/bad-repeated passes=passes/identity" 2>&1 \
// RUN:   | %FileCheck %s --check-prefix=REPEATED

// UNKNOWN: badtest.op: unknown trait: terminatr
// REPEATED: badtest.op: repeated trait: terminator

module {}
