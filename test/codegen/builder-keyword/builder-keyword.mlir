// Tests :builder keyword — binds the active rewriter as a Scheme value.
// Pattern: test.copy(%v) → test.identity(%v).
// (b = :builder) verifies the builder is a live non-null object.
//
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt -allow-unregistered-dialect \
// RUN:   --crest-pass="module=passes/builder-keyword" %s \
// RUN:   | %FileCheck %s

// CHECK-LABEL: func.func @test_i32
// CHECK:         "test.identity"(%arg0) : (i32) -> i32
// CHECK-NOT:     test.copy

func.func @test_i32(%arg0: i32) -> i32 {
  %0 = "test.copy"(%arg0) : (i32) -> i32
  return %0 : i32
}
