// What the canonicalizer does with a folder that answers wrongly or in place.
//
// REQUIRES: llvm-23
// RUN: rm -rf %t/op-fold-errors-scheme && mkdir -p %t/op-fold-errors-scheme
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/op-fold-errors-scheme \
// RUN:   %crest-opt %s --split-input-file --verify-diagnostics --mlir-disable-threading \
// RUN:   --crest-scheme-dialect=ocb=passes/ocb --canonicalize

// expected-error @+1 {{fold callback: a result must be made by fold-value or fold-attribute}}
%0 = "ocb.malformed"() : () -> i64

// -----

// expected-error @+1 {{fold callback returned 2 results for an op with 1}}
%0 = "ocb.toomany"() : () -> i64
