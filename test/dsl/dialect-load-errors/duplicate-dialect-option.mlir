// --crest-scheme-dialect twice for the same dialect: the same library is given once, another library for
// the same dialect name is an error of the command line, not a crash of LLVM.
//
// RUN: rm -rf %t/duplicate-dialect-scheme && mkdir -p %t/duplicate-dialect-scheme
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/duplicate-dialect-scheme \
// RUN:   %crest-opt %s --mlir-disable-threading --crest-scheme-dialect=simple=passes/simple \
// RUN:   --crest-scheme-dialect=simple=passes/simple | %FileCheck %s
// RUN: not env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/duplicate-dialect-scheme \
// RUN:   %crest-opt %s --mlir-disable-threading --crest-scheme-dialect=simple=passes/simple \
// RUN:   --crest-scheme-dialect=simple=passes/simple2 2>&1 | %FileCheck %s --check-prefix=OTHER

// CHECK: "simple.thing"() : () -> ()
// OTHER: crest-opt: --crest-scheme-dialect: dialect 'simple' is given for passes/simple and for passes/simple2

module {
  "simple.thing"() : () -> ()
}
