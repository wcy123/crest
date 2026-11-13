// What the canonicalizer does with a folder that answers wrongly or in place. An error of the folder is a
// diagnostic at its Scheme source, and the fold fails.
//
// REQUIRES: llvm-23
// RUN: rm -rf %t/op-fold-errors-scheme && mkdir -p %t/op-fold-errors-scheme
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/op-fold-errors-scheme \
// RUN:   %crest-opt %s --split-input-file --mlir-disable-threading \
// RUN:   --crest-scheme-dialect=ocb=passes/ocb --canonicalize 2>&1 | %FileCheck %s

// CHECK: error: {{.*}}ocb.sls:{{[0-9]+}}:{{[0-9]+}}: fold callback: a result must be made by fold-value or fold-attribute
// CHECK: op-fold-errors.mlir:{{[0-9]+}}:{{[0-9]+}}: error: fold callback returned 2 results for an op with 1

%0 = "ocb.malformed"() : () -> i64

// -----

%0 = "ocb.toomany"() : () -> i64
