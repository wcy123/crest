// Mistakes in the names of :traits are reported when the dialect loads (the table of names is C++).
//
// REQUIRES: llvm-23
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/traits-err-unknown \
// RUN:   not %crest-opt %s --crest-scheme-dialect=badtest=passes/bad-unknown 2>&1 \
// RUN:   | %FileCheck %s --check-prefix=UNKNOWN
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/traits-err-repeated \
// RUN:   not %crest-opt %s --crest-scheme-dialect=badtest=passes/bad-repeated 2>&1 \
// RUN:   | %FileCheck %s --check-prefix=REPEATED

// UNKNOWN: badtest.op: unknown trait: terminatr
// REPEATED: badtest.op: repeated trait: terminator

"badtest.op"() : () -> ()
