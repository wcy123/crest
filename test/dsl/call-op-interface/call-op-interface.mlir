// CallOpInterface for ops of a Scheme dialect (plans/13, part 2). MLIR's inliner finds the callee of
// a call through the interface: calltest.call must answer getCallableForCallee (its callee
// attribute), getArgOperands (its operands) and resolve the symbol, calltest.func must be callable.
// With them, --inline replaces the call with the body of the callee, and --symbol-dce then drops
// the private callee.
//
// Needs LLVM 23: calltest.ret declares the terminator trait, and before LLVM 23 the verifier rejects any
// block of a Scheme dialect (there is no way to say which op ends it).
//
// REQUIRES: llvm-23
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/call \
// RUN:   %crest-opt %s --crest-scheme-dialect=calltest=passes/call-dialect \
// RUN:   --inline --symbol-dce | %FileCheck %s

// CHECK-NOT: calltest.call
// CHECK: "calltest.ret"(%arg0)
// CHECK: sym_name = "main"

module {
  "calltest.func"() ({
  ^bb0(%a: i32):
    "calltest.ret"(%a) : (i32) -> ()
  }) {function_type = (i32) -> i32, sym_name = "callee", sym_visibility = "private"} : () -> ()
  "calltest.func"() ({
  ^bb0(%x: i32):
    %r = "calltest.call"(%x) {callee = @callee} : (i32) -> i32
    "calltest.ret"(%r) : (i32) -> ()
  }) {function_type = (i32) -> i32, sym_name = "main"} : () -> ()
}
