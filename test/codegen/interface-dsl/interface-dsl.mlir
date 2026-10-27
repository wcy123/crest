// Unit test: :interfaces DSL generates dispatcher and registers
// mlir::FunctionOpInterface for an op.
//
// Tests two dialect variants:
//   - ifacetest:  no method overrides (all C++ defaults)
//   - ifacetest2: explicit overrides delegating to C++ defaults
//
// If interface registration fails (e.g. wrong dispatcher shape), the pass
// crashes before reaching FileCheck.

// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt -allow-unregistered-dialect \
// RUN:   --crest-pass="module=passes/interface-dsl" %s \
// RUN:   | %FileCheck %s

// CHECK: module
module {
}
