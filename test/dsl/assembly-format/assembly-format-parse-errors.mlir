// A text that does not match its format is a parse error at the offending token, as for any op.
//
// RUN: not env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/af-err \
// RUN:   %crest-opt %s --mlir-disable-threading --crest-scheme-dialect=af=passes/af --split-input-file 2>&1 \
// RUN:   | %FileCheck %s

// A keyword literal that is not there.
// CHECK: error: custom op 'af.with' expected 'with'
func.func @keyword(%a: i32) {
  af.with %a : i32
  return
}

// -----

// A punctuation literal that is not there.
// CHECK: error: expected ':'
func.func @colon(%a: i32) {
  af.unary %a i32 to f32
  return
}

// -----

// A functional type whose result count is not the op's.
// CHECK: error: custom op 'af.call' expected 1 result type(s) in the functional type
func.func @results(%a: i32) {
  %0 = af.call @f(%a) : (i32) -> (f32, f32)
  return
}

// -----

// The operand's type is not the one given.
// CHECK: error: use of value '%a' expects different type than prior uses: 'i64' vs 'i32'
func.func @type(%a: i32) {
  af.unary %a : i64 to f32
  return
}

// -----

// An optional group whose operand is there needs the rest of its elements.
// CHECK: error: expected ':'
func.func @group(%a: i32) {
  af.ret %a
  return
}
