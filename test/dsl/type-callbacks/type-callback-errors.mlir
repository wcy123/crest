// A verifier that says no without a message, a parser that fails after saying why, and a verifier
// that raises a Scheme error (the process must go on: the verifier fails, the diagnostic has the
// text of the error at the Scheme source of the verifier, and MLIR adds its own message for the failure;
// so the output is checked with FileCheck).

// RUN: rm -rf %t/type-callback-errors-scheme && mkdir -p %t/type-callback-errors-scheme
// RUN: not env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/type-callback-errors-scheme \
// RUN:   %crest-opt %s --split-input-file --mlir-disable-threading \
// RUN:   --crest-scheme-dialect=tcb=passes/tcb 2>&1 | %FileCheck %s

// CHECK: error: invalid type parameters
// CHECK: error: this type cannot be parsed
// CHECK: tcb.sls:{{[0-9]+}}:{{[0-9]+}}: error: verify: the type verifier is broken
// CHECK: error: invalid type parameters

func.func @f(%a: !tcb.bad) {
  return
}

// -----

func.func @f(%a: !tcb.broken) {
  return
}

// -----

func.func @f(%a: !tcb.raises) {
  return
}
