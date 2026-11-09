// A verifier of an op that fails after saying why, and one that raises a Scheme error (the process
// must go on: the verifier fails and the diagnostic has the text of the error).

// RUN: rm -rf %t/op-callback-errors-scheme && mkdir -p %t/op-callback-errors-scheme
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/op-callback-errors-scheme \
// RUN:   %crest-opt %s --split-input-file --verify-diagnostics --mlir-disable-threading \
// RUN:   --crest-scheme-dialect=ocb=passes/ocb

// expected-error @+1 {{the op is not allowed}}
"ocb.bad"() : () -> ()

// -----

// expected-error @+1 {{the regions are not allowed}}
"ocb.badregions"() : () -> ()

// -----

// expected-error @+1 {{the verifier is broken}}
"ocb.raises"() : () -> ()
