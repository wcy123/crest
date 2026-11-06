// A result type after -> must be an mlir::Type. A parenthesised form after -> is a list of types,
// so -> (mlir::IndexType::get) holds the procedure itself. That used to reach the FFI and fail
// with "invalid foreign-procedure argument"; the error must name the op and the rule instead. The
// failed rewrite is reported as an error diagnostic and the pass leaves the op alone.
//
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt -allow-unregistered-dialect \
// RUN:   --crest-pass="passes=passes/call-as-type" %s 2>&1 | %FileCheck %s

// CHECK: Exception in begin-mlir-code: the result type of test.dst is a procedure, not an mlir::Type
// CHECK-SAME: a parenthesised form after -> is a list of types; bind a call to a variable first

func.func @f() {
  "test.src"() : () -> ()
  return
}
