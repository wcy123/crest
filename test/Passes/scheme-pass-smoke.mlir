// RUN: %crest-opt %s | %FileCheck %s

// Smoke test: verify crest-opt can parse a basic MLIR module and round-trip it.
// CHECK: module
// CHECK: func.func @hello
// CHECK: return

module {
  func.func @hello() {
    return
  }
}
