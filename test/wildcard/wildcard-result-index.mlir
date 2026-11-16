// The result that a pattern names must be the result that the consumer uses.
// (_ %second) = test.split (%x), %out = test.use (%second) is about result 1 of test.split:
// a test.use of result 0 is not that pattern and must be left alone.

// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt -allow-unregistered-dialect \
// RUN:   --crest-pass="passes=passes/wildcard-result" %s \
// RUN:   | %FileCheck %s

// CHECK-LABEL: func.func @uses_first_result
// CHECK:       %[[SPLIT:.*]]:2 = "test.split"
// CHECK:       "test.use"(%[[SPLIT]]#0)
// CHECK-NOT:   test.fused

// CHECK-LABEL: func.func @uses_second_result
// CHECK:       "test.fused"

func.func @uses_first_result() -> i32 {
  %x       = "test.input"() : () -> i32
  %r0, %r1 = "test.split"(%x) : (i32) -> (i32, i32)
  %out     = "test.use"(%r0)  : (i32) -> i32
  return %out : i32
}

func.func @uses_second_result() -> i32 {
  %x       = "test.input"() : () -> i32
  %r0, %r1 = "test.split"(%x) : (i32) -> (i32, i32)
  %out     = "test.use"(%r1)  : (i32) -> i32
  return %out : i32
}
