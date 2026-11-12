// A verifier of an op that fails after saying why, and one that raises a Scheme error (the process
// must go on: the verifier fails, and the diagnostic has the text of the error, at the Scheme source
// of the verifier, so the output is checked with FileCheck).

// RUN: rm -rf %t/op-callback-errors-scheme && mkdir -p %t/op-callback-errors-scheme
// RUN: not env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/op-callback-errors-scheme \
// RUN:   %crest-opt %s --split-input-file --mlir-disable-threading \
// RUN:   --crest-scheme-dialect=ocb=passes/ocb 2>&1 | %FileCheck %s

// CHECK: error: the op is not allowed
// CHECK: error: the regions are not allowed
// CHECK: ocb.sls:{{[0-9]+}}:{{[0-9]+}}: error: verify: the verifier is broken

"ocb.bad"() : () -> ()

// -----

"ocb.badregions"() : () -> ()

// -----

"ocb.raises"() : () -> ()
