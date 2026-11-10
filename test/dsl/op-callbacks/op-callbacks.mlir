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
// :populate-default-attrs fills the NamedAttrList of an op that is created without the attribute, and
// leaves the one it finds (the second ocb.defaults has its own level), as `get` and `append` say; `set`
// replaces the mode of ocb.overrides and adds it when it is missing.
// CHECK: "ocb.defaults"() {level = 7 : i32} : () -> ()
// CHECK: "ocb.defaults"() {level = 3 : i32} : () -> ()
// CHECK: "ocb.overrides"() {mode = "default"} : () -> ()
// CHECK: "ocb.overrides"() {mode = "default"} : () -> ()

module {
  "ocb.regions"() : () -> ()
  "ocb.verified"() : () -> ()
  "ocb.defaults"() : () -> ()
  "ocb.defaults"() {level = 3 : i32} : () -> ()
  "ocb.overrides"() : () -> ()
  "ocb.overrides"() {mode = "mine"} : () -> ()
}
