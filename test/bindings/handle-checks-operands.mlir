// resolveOperands, resolveOperandsFunctional and freeOperands answer an error (Rule 20) when they are
// given a type that is 0 or not a function type, or an operand-list handle that is 0 or of another
// kind. A parse that fails answers 0, and Scheme that does not look passes the 0 on. Each case is a run
// of its own (a fault ends the process); see handle-checks-operands.sls.
//
// RUN: %scheme-mlir %S/handle-checks-operands.sls resolve-type 2>&1 | %FileCheck %s --check-prefix=RESOLVE-TYPE
// RUN: %scheme-mlir %S/handle-checks-operands.sls resolve-list-null 2>&1 | %FileCheck %s --check-prefix=RESOLVE-LIST
// RUN: %scheme-mlir %S/handle-checks-operands.sls resolve-list-wrong 2>&1 | %FileCheck %s --check-prefix=RESOLVE-LIST
// RUN: %scheme-mlir %S/handle-checks-operands.sls free-null 2>&1 | %FileCheck %s --check-prefix=FREE-NULL
// RUN: %scheme-mlir %S/handle-checks-operands.sls free-wrong 2>&1 | %FileCheck %s --check-prefix=FREE-WRONG
// RUN: %scheme-mlir %S/handle-checks-operands.sls resolve-functional 2>&1 | %FileCheck %s --check-prefix=RESOLVE-FUNCTIONAL

// RESOLVE-TYPE: mlir::OpAsmParser::resolveOperands: type pointer is null
// RESOLVE-LIST: mlir::OpAsmParser::resolveOperands: {{.*}} not a list of operands
// FREE-NULL: no error
// FREE-WRONG: crest::OpAsmParser::freeOperands: not a list of operands
// RESOLVE-FUNCTIONAL: mlir::OpAsmParser::resolveOperandsFunctional: {{.*}} not a function type

module {}
