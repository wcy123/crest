// The verifier of a dialect type runs when the type is built.
//
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/types-err \
// RUN:   not %crest-opt %s --mlir-disable-threading --crest-scheme-dialect=dt=passes/type-dialect 2>&1 \
// RUN:   | %FileCheck %s

// CHECK: dialect-types-errors.mlir:{{[0-9]+}}:{{[0-9]+}}: error: a pair has two different element types

func.func @f(%a: !dt.pair<i32, i32>) {
  return
}
