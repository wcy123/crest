// Mistakes in the arguments of a trait are reported when the dialect loads.
//
// REQUIRES: llvm-23
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/err \
// RUN:   %crest-opt %s --crest-pass="dialects-in-scheme=badtest=passes/bad-has-parent passes=passes/identity" 2>&1 \
// RUN:   | %FileCheck %s --check-prefix=NOPARENT

// NOPARENT: badtest.op: has-parent needs at least one parent op name

module {}
