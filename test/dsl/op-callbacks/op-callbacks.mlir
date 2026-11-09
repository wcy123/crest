// The callbacks of an op that no other test has: :verify-regions, :verify and
// :populate-default-attrs run when MLIR asks for them.

// RUN: rm -rf %t/op-callbacks-scheme && mkdir -p %t/op-callbacks-scheme
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/op-callbacks-scheme \
// RUN:   %crest-opt %s --mlir-disable-threading --crest-scheme-dialect=ocb=passes/ocb \
// RUN:   > %t/op-callbacks-out.txt
// RUN: %FileCheck %s --check-prefix=SAY --input-file=%t/op-callbacks-out.txt
// RUN: %FileCheck %s --input-file=%t/op-callbacks-out.txt

// SAY-DAG: populate-default-attrs
// SAY-DAG: verify-regions
// SAY-DAG: verify

// CHECK: "ocb.regions"() : () -> ()
// CHECK: "ocb.verified"() : () -> ()
// CHECK: "ocb.defaults"() : () -> ()

module {
  "ocb.regions"() : () -> ()
  "ocb.verified"() : () -> ()
  "ocb.defaults"() : () -> ()
}
