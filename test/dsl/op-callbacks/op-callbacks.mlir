// The callbacks of an op that no other test has: :verify-regions, :verify and
// :populate-default-attrs run when MLIR asks for them.

// RUN: rm -rf %t/op-callbacks-scheme && mkdir -p %t/op-callbacks-scheme
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/op-callbacks-scheme \
// RUN:   %crest-opt %s --mlir-disable-threading --crest-scheme-dialect=ocb=passes/ocb \
// RUN:   > %t/op-callbacks-out.txt 2> %t/op-callbacks-err.txt
// RUN: %FileCheck %s --check-prefix=ERR --input-file=%t/op-callbacks-err.txt
// RUN: %FileCheck %s --input-file=%t/op-callbacks-out.txt

// ERR-DAG: populate-default-attrs
// ERR-DAG: verify-regions
// ERR-DAG: verify

// CHECK: "ocb.regions"() : () -> ()
// CHECK: "ocb.verified"() : () -> ()
// CHECK: "ocb.defaults"() : () -> ()

module {
  "ocb.regions"() : () -> ()
  "ocb.verified"() : () -> ()
  "ocb.defaults"() : () -> ()
}
