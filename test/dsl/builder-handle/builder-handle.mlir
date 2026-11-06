// A pattern's rewriter is a CrestBox<RewriterBase*> shell. The OpBuilder bindings take that shell
// as a builder: the Scheme side checks the shell's type and calls the C++ symbol for that kind
// (the upcast adjusts the address because RewriterBase is polymorphic and its OpBuilder base is
// not at offset 0). A null handle is an error.
//
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt -allow-unregistered-dialect \
// RUN:   --crest-pass="passes=passes/builder-handle" %s \
// RUN:   | %FileCheck %s

// CHECK-LABEL: func.func @test_i32
// CHECK:         "test.out"(%arg0) : (i32) -> i32
// CHECK-NOT:     test.in

func.func @test_i32(%arg0: i32) -> i32 {
  %0 = "test.in"(%arg0) : (i32) -> i32
  return %0 : i32
}
