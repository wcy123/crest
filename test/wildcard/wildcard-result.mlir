// %_ in result position — result 0 of test.split is discarded; only result 1 is used.

// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt -allow-unregistered-dialect \
// RUN:   --crest-pass="module=passes/wildcard-result" %s \
// RUN:   | %FileCheck %s

// CHECK-LABEL: func.func @result_wildcard
// CHECK:       %[[X:.*]] = "test.input"
// CHECK:       "test.fused"(%[[X]]) : (i32) -> i32
// CHECK-NOT:   test.use

func.func @result_wildcard() -> i32 {
  %x             = "test.input"() : () -> i32
  %r0, %r1       = "test.split"(%x) : (i32) -> (i32, i32)
  %out           = "test.use"(%r1)  : (i32) -> i32
  return %out : i32
}
