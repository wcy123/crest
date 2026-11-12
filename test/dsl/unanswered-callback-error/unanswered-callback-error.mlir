// The error of a callback needs somebody to raise it, when the binding that ran the callback returns.
//
// In a Scheme program that is the binding (CrestDialect::initialize runs inside getOrLoadDialect, called
// by the pass below): the error is a Scheme error that the pass catches, and the process goes on.
//
// In crest-opt MLIR drives: the parser loads the dialect when the file uses it, and no Scheme program is
// there to raise anything (failIfUnanswered). The process stops with the text and a failure status.
//
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/pass \
// RUN:   %crest-opt %S/empty.in --mlir-disable-threading --crest-scheme-dialect=badd=passes/bad-dialect \
// RUN:   --crest-pass="passes=passes/load-bad" 2>&1 | %FileCheck %s --check-prefix=PASS
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/parse \
// RUN:   not %crest-opt %s --mlir-disable-threading --crest-scheme-dialect=badd=passes/bad-dialect 2>&1 \
// RUN:   | %FileCheck %s --check-prefix=PARSE

// PASS: caught: initialize failed
// PASS-NOT: not raised

// PARSE: badd: initialize failed

func.func @f(%a: i32) -> i32 {
  %0 = "badd.ping"(%a) : (i32) -> i32
  return %0 : i32
}
