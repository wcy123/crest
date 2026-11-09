// A type of a Scheme dialect with no parameters is parsed from its name and printed back, and an op
// can ask for it.

// RUN: rm -rf %t/type-callbacks-scheme && mkdir -p %t/type-callbacks-scheme
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/type-callbacks-scheme \
// RUN:   %crest-opt %s --mlir-disable-threading --crest-scheme-dialect=tcb=passes/tcb | %FileCheck %s

// CHECK: func.func @f(%arg0: !tcb.empty) -> !tcb.empty
// CHECK: "tcb.make"() : () -> !tcb.empty

func.func @f(%a: !tcb.empty) -> !tcb.empty {
  %0 = "tcb.make"() : () -> !tcb.empty
  return %0 : !tcb.empty
}
