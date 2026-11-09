// A verifier that says no without a message, a parser that fails after saying why, and a verifier
// that raises a Scheme error (the process must go on: the verifier fails and the diagnostic has the
// text of the error).

// RUN: rm -rf %t/type-callback-errors-scheme && mkdir -p %t/type-callback-errors-scheme
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/type-callback-errors-scheme \
// RUN:   %crest-opt %s --split-input-file --verify-diagnostics --mlir-disable-threading \
// RUN:   --crest-scheme-dialect=tcb=passes/tcb

// expected-error @+1 {{invalid type parameters}}
func.func @f(%a: !tcb.bad) {
  return
}

// -----

// expected-error @+1 {{this type cannot be parsed}}
func.func @f(%a: !tcb.broken) {
  return
}

// -----

// expected-error @+1 {{the type verifier is broken}}
func.func @f(%a: !tcb.raises) {
  return
}
