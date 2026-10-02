// RUN: %crest-opt --scheme-pass="module=passes/print" %s 2>&1 | %FileCheck %s
// CHECK: scheme-pass: module loaded

// Smoke test: verify SchemePass initializes the Chez runtime, imports the
// Scheme library, and calls run-pass without crashing. The Scheme library
// (passes/print.sls) is expected to emit the CHECK line to stderr and
// return without modifying the IR.

module {
  func.func @hello() {
    return
  }
}
