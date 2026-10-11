// Linear chain topology: A → B → C → D
//
//   %a ──► test.mul ──► %b ──► test.add ──► %c ──► test.sub ──► %d
//
// Each :set-current-op walks one hop up the def-use chain.
// Pattern rewrites to test.fused(%a, %x, %y).

// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt -allow-unregistered-dialect \
// RUN:   --crest-pass="module=passes/network-chain" %s \
// RUN:   | %FileCheck %s

// CHECK-LABEL: func.func @chain
// CHECK:       "test.fused"(%arg0, %arg1, %arg2) : (i32, i32, i32) -> i32
// CHECK-NOT:   test.sub

func.func @chain(%a: i32, %x: i32, %y: i32) -> i32 {
  %b = "test.mul"(%a)    : (i32) -> i32
  %c = "test.add"(%b, %x) : (i32, i32) -> i32
  %d = "test.sub"(%c, %y) : (i32, i32) -> i32
  return %d : i32
}
