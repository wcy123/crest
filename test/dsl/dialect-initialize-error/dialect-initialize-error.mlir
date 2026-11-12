// A :initialize callback that raises is reported as a diagnostic. MLIR calls CrestDialect::initialize, which
// cannot fail (it returns void), so the C++ code that gets the error from the callback prints it and returns:
// the program goes on, in crest-opt (the parser loads the dialect when the file uses it) and in a Scheme
// pass (getOrLoadDialect loads it).
//
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/pass \
// RUN:   %crest-opt %S/empty.in --mlir-disable-threading --crest-scheme-dialect=badd=passes/bad-dialect \
// RUN:   --crest-pass="passes=passes/load-bad" 2>&1 | %FileCheck %s --check-prefix=PASS
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/parse \
// RUN:   %crest-opt %s --mlir-disable-threading --crest-scheme-dialect=badd=passes/bad-dialect 2>&1 \
// RUN:   | %FileCheck %s --check-prefix=PARSE

// PASS: error: badd: initialize failed
// PASS: not raised

// PARSE: error: badd: initialize failed
// PARSE: "badd.ping"

func.func @f(%a: i32) -> i32 {
  %0 = "badd.ping"(%a) : (i32) -> i32
  return %0 : i32
}
