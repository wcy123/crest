// An op's own canonicalization patterns (the `hasCanonicalizer` of C++ ops): :get-canonicalization-patterns
// registers them, and the canonicalizer finds them without the tool registering anything.
//
// REQUIRES: llvm-23
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/canon \
// RUN:   %crest-opt %s --mlir-disable-threading --crest-scheme-dialect=oc=passes/canon-ops --canonicalize \
// RUN:   | %FileCheck %s

// CHECK-LABEL: func.func @f
// CHECK-NOT:     "oc.neg"
// CHECK:         return %arg0

func.func @f(%a: i32) -> i32 {
  %0 = "oc.neg"(%a) : (i32) -> i32
  %1 = "oc.neg"(%0) : (i32) -> i32
  return %1 : i32
}
