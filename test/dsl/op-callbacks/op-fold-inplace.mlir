// A folder that changes the op and answers '() has folded it in place.
//
// REQUIRES: llvm-23
// RUN: rm -rf %t/op-fold-inplace-scheme && mkdir -p %t/op-fold-inplace-scheme
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/op-fold-inplace-scheme \
// RUN:   %crest-opt %s --mlir-disable-threading --crest-scheme-dialect=ocb=passes/ocb --canonicalize \
// RUN:   | %FileCheck %s

// CHECK: "ocb.inplace"() {done} : () -> i64

func.func @f() -> i64 {
  %0 = "ocb.inplace"() : () -> i64
  return %0 : i64
}
