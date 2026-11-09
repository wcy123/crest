// What the dialect says about the attributes that carry its name: a verifier that answers #f after
// emitting an error, and one that raises a Scheme error (the process must go on: the verifier
// fails and the diagnostic has the text of the error).

// RUN: rm -rf %t/dialect-callback-errors-scheme && mkdir -p %t/dialect-callback-errors-scheme
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/dialect-callback-errors-scheme \
// RUN:   %crest-opt %s --split-input-file --verify-diagnostics --mlir-disable-threading \
// RUN:   --crest-scheme-dialect=dcbdep=passes/dcbdep --crest-scheme-dialect=dcb=passes/dcb

// expected-error @+1 {{the attribute is not allowed}}
"dcb.bad"() {dcb.flag = 1 : i32} : () -> ()

// -----

// expected-error @+1 {{the argument attribute is not allowed}}
func.func @f(%a: i32, %b: i32, %c: i32 {dcb.flag = 1 : i32}) {
  return
}

// -----

// expected-error @+1 {{the attribute is broken}}
"dcb.raises"() {dcb.flag = 1 : i32} : () -> ()
