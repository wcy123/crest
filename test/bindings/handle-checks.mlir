// A binding that is given a handle it cannot use answers an error (Rule 20): it does not crash. A parse
// that fails answers 0, and Scheme that does not look passes the 0 on to the next call; a pointer that
// is the wrong kind of object has to be refused too. Each case is a run of its own (a crash ends the
// process); see handle-checks.sls.
//
// RUN: %scheme-mlir %S/handle-checks.sls parse-operand 2>&1 | %FileCheck %s --check-prefix=PARSE-OPERAND
// RUN: %scheme-mlir %S/handle-checks.sls parse-colon 2>&1 | %FileCheck %s --check-prefix=PARSE-COLON
// RUN: %scheme-mlir %S/handle-checks.sls parse-keyword 2>&1 | %FileCheck %s --check-prefix=PARSE-KEYWORD
// RUN: %scheme-mlir %S/handle-checks.sls parse-attribute 2>&1 | %FileCheck %s --check-prefix=PARSE-ATTRIBUTE
// RUN: %scheme-mlir %S/handle-checks.sls print-string 2>&1 | %FileCheck %s --check-prefix=PRINT-STRING
// RUN: %scheme-mlir %S/handle-checks.sls asm-print-type 2>&1 | %FileCheck %s --check-prefix=ASM-PRINT-TYPE
// RUN: %scheme-mlir %S/handle-checks.sls print-operand 2>&1 | %FileCheck %s --check-prefix=PRINT-OPERAND
// RUN: %scheme-mlir %S/handle-checks.sls resolve-type 2>&1 | %FileCheck %s --check-prefix=RESOLVE-TYPE
// RUN: %scheme-mlir %S/handle-checks.sls resolve-list-null 2>&1 | %FileCheck %s --check-prefix=RESOLVE-LIST
// RUN: %scheme-mlir %S/handle-checks.sls resolve-list-wrong 2>&1 | %FileCheck %s --check-prefix=RESOLVE-LIST
// RUN: %scheme-mlir %S/handle-checks.sls free-null 2>&1 | %FileCheck %s --check-prefix=FREE-NULL
// RUN: %scheme-mlir %S/handle-checks.sls free-wrong 2>&1 | %FileCheck %s --check-prefix=FREE-WRONG
// RUN: %scheme-mlir %S/handle-checks.sls resolve-functional 2>&1 | %FileCheck %s --check-prefix=RESOLVE-FUNCTIONAL
// RUN: %scheme-mlir %S/handle-checks.sls engine-null 2>&1 | %FileCheck %s --check-prefix=ENGINE-NULL
// RUN: %scheme-mlir %S/handle-checks.sls engine-not-module 2>&1 | %FileCheck %s --check-prefix=ENGINE-NOT-MODULE
// RUN: %scheme-mlir %S/handle-checks.sls run-null 2>&1 | %FileCheck %s --check-prefix=RUN-NULL
// RUN: %scheme-mlir %S/handle-checks.sls add-pass-null 2>&1 | %FileCheck %s --check-prefix=ADD-PASS
// RUN: %scheme-mlir %S/handle-checks.sls arith-add-null 2>&1 | %FileCheck %s --check-prefix=ARITH-ADD
// RUN: %scheme-mlir %S/handle-checks.sls arith-constant-null 2>&1 | %FileCheck %s --check-prefix=ARITH-CONSTANT-NULL
// RUN: %scheme-mlir %S/handle-checks.sls arith-constant-untyped 2>&1 | %FileCheck %s --check-prefix=ARITH-CONSTANT-UNTYPED

// RUN: %scheme-mlir %S/handle-checks.sls scf-forop-null 2>&1 | %FileCheck %s --check-prefix=SCF-NULL
// RUN: %scheme-mlir %S/handle-checks.sls string-attr-null 2>&1 | %FileCheck %s --check-prefix=STRING-ATTR
// RUN: %scheme-mlir %S/handle-checks.sls function-type-wrong 2>&1 | %FileCheck %s --check-prefix=FUNCTION-TYPE
// RUN: %scheme-mlir %S/handle-checks.sls func-body-wrong 2>&1 | %FileCheck %s --check-prefix=FUNC-BODY
// RUN: %scheme-mlir %S/handle-checks.sls module-body-wrong 2>&1 | %FileCheck %s --check-prefix=MODULE-BODY

// PARSE-OPERAND: mlir::OpAsmParser::parseOperand: parser pointer is null
// PARSE-COLON: mlir::OpAsmParser::parseColon: parser pointer is null
// PARSE-KEYWORD: mlir::OpAsmParser::parseKeyword: parser pointer is null
// PARSE-ATTRIBUTE: mlir::OpAsmParser::parseAttribute: parser pointer is null
// PRINT-STRING: mlir::OpAsmPrinter::printString: printer pointer is null
// ASM-PRINT-TYPE: mlir::AsmPrinter::printType: printer pointer is null
// PRINT-OPERAND: mlir::OpAsmPrinter::printOperand: value pointer is null
// RESOLVE-TYPE: mlir::OpAsmParser::resolveOperands: type pointer is null
// RESOLVE-LIST: mlir::OpAsmParser::resolveOperands: {{.*}} not a list of operands
// FREE-NULL: no error
// FREE-WRONG: crest::OpAsmParser::freeOperands: not a list of operands
// RESOLVE-FUNCTIONAL: mlir::OpAsmParser::resolveOperandsFunctional: {{.*}} not a function type
// ENGINE-NULL: mlir::ExecutionEngine::create: module pointer is null
// ENGINE-NOT-MODULE: mlir::ExecutionEngine::create: {{.*}} not a module
// RUN-NULL: mlir::PassManager::run!: module pointer is null
// ADD-PASS: mlir::OpPassManager::addPass: pass manager pointer is null
// ARITH-ADD: mlir::arith::AddFOp::create: lhs pointer is null
// ARITH-CONSTANT-NULL: mlir::arith::ConstantOp::create<f64>: attribute pointer is null
// ARITH-CONSTANT-UNTYPED: mlir::arith::ConstantOp::create<f64>: {{.*}} not a typed attribute

// SCF-NULL: mlir::scf::ForOp::getBody: operation pointer is null
// STRING-ATTR: mlir::StringAttr::getValue: the pointer is null or not a StringAttr
// FUNCTION-TYPE: mlir::FunctionType::getNumInputs: the pointer is null or not a FunctionType
// FUNC-BODY: mlir::func::FuncOp::getBody: the pointer is null or not a FuncOp
// MODULE-BODY: mlir::ModuleOp::getBody: the operation is not a module

module {}
