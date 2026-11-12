// A :initialize callback that raises ends the process with the text of the error. MLIR calls
// CrestDialect::initialize, which cannot fail (it returns void), so there is no place for the error: its callable
// has the C result type void, and the guard of such a callable ends the process (Rule 20). It does in crest-opt (the
// parser loads the dialect when the file uses it) and in a Scheme pass (getOrLoadDialect loads it).
//
// RUN: not env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/pass \
// RUN:   %crest-opt %S/empty.in --mlir-disable-threading --crest-scheme-dialect=badd=passes/bad-dialect \
// RUN:   --crest-pass="passes=passes/load-bad" 2>&1 | %FileCheck %s --check-prefix=PASS
// RUN: not env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/parse \
// RUN:   %crest-opt %s --mlir-disable-threading --crest-scheme-dialect=badd=passes/bad-dialect 2>&1 \
// RUN:   | %FileCheck %s --check-prefix=PARSE

// PASS: LLVM ERROR: badd: initialize failed
// PASS-NOT: not raised
// PARSE: LLVM ERROR: badd: initialize failed

func.func @f(%a: i32) -> i32 {
  %0 = "badd.ping"(%a) : (i32) -> i32
  return %0 : i32
}
