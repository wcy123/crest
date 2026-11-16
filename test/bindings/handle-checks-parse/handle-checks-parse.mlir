// A parse callback that does not look at the 0 that parseOperandList returns for a failed parse, and gives it to
// resolveOperands. The binding checks its handle (Rule 20) and returns an error; the guard of the callback reports
// it as a diagnostic (Rule 17), and MLIR sees the parse fail. Without the check, crest-opt reads address 0 and crashes.
//
// RUN: not env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt %s --crest-scheme-dialect=pforgets=passes/parse-forgets 2>&1 | %FileCheck %s

// CHECK: mlir::OpAsmParser::resolveOperands: the operand list is null or not a list of operands

// The op needs two operands, and the text has one.
func.func @f(%a: i32) {
  pforgets.op %a : i32
  return
}
