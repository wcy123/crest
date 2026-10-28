// Tests that dialects= pre-loads the listed dialects before the Scheme pass
// runs. The func dialect must be pre-loaded for func.func ops to be parsed
// correctly.

// RUN: env CREST_PATH=%S \
// RUN:   %crest-opt %s \
// RUN:   --crest-pass="passes=passes/dialect-preload dialects=func" \
// RUN:   | %FileCheck %s

// CHECK: first-op: func.func

module {
  func.func @test() {
    return
  }
}
