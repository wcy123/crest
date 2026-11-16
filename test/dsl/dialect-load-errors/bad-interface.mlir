// A dialect-level :interfaces entry that a dialect cannot have (only mlir::DialectInlinerInterface is one)
// is an error when the dialect loads, and its ops are not registered.
//
// RUN: rm -rf %t/bad-interface-scheme && mkdir -p %t/bad-interface-scheme
// RUN: not env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/bad-interface-scheme \
// RUN:   %crest-opt %s --mlir-disable-threading --crest-scheme-dialect=badiface=passes/badiface 2>&1 \
// RUN:   | %FileCheck %s

// CHECK: error: crest::CrestDialect: no way to install an interface of :interfaces

module {
  "badiface.thing"() : () -> ()
}
