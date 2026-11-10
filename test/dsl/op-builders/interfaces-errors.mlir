// The :interfaces clause of define-op: an entry of InferTypeOpInterface must have its inferReturnTypes
// clause, and the clause is a list of entries. Both are reported with their reason, not as a crash.
//
// RUN: not env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt %s --mlir-disable-threading --crest-scheme-dialect=noinf=passes/no-infer-dialect 2>&1 \
// RUN:   | %FileCheck %s --check-prefix=NOINFER
// RUN: not env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt %s --mlir-disable-threading --crest-scheme-dialect=badi=passes/bad-interfaces-dialect 2>&1 \
// RUN:   | %FileCheck %s --check-prefix=BADLIST

// NOINFER: error: Failed to import Scheme library: passes/no-infer-dialect: {{.*}}the interface needs an inferReturnTypes clause
// BADLIST: error: Failed to import Scheme library: passes/bad-interfaces-dialect: {{.*}}:interfaces expects a list of (interface-name method-clause ...)

func.func @f(%a: i32) {
  "noinf.op"(%a) : (i32) -> i32
  "badi.op"(%a) : (i32) -> i32
  return
}
