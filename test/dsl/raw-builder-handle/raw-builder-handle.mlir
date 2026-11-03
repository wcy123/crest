// A pattern's rewriter is a CrestRef<RewriterBase> shell. crest::as_ptr<mlir::OpBuilder>
// unwraps it to a raw OpBuilder* (the C++ upcast adjusts the address: RewriterBase is
// polymorphic, so its OpBuilder base is not at offset 0). Builder bindings take that raw
// pointer. Unwrapping a raw pointer again is an error.
//
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt -allow-unregistered-dialect \
// RUN:   --crest-pass="passes=passes/raw-builder-handle" %s \
// RUN:   | %FileCheck %s

// CHECK-LABEL: func.func @test_i32
// CHECK:         "test.out"(%arg0) : (i32) -> i32
// CHECK-NOT:     test.in

func.func @test_i32(%arg0: i32) -> i32 {
  %0 = "test.in"(%arg0) : (i32) -> i32
  return %0 : i32
}
