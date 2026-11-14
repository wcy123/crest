// A binding that is given a pointer that is 0 answers an error (Rule 20): it does not crash. A parse
// that fails answers 0, and Scheme that does not look passes the 0 on to the next call. Each case is a
// run of its own (a crash ends the process); see handle-checks-null.sls.
//
// RUN: %scheme-mlir %S/handle-checks-null.sls parse-operand 2>&1 | %FileCheck %s --check-prefix=PARSE-OPERAND
// RUN: %scheme-mlir %S/handle-checks-null.sls parse-colon 2>&1 | %FileCheck %s --check-prefix=PARSE-COLON
// RUN: %scheme-mlir %S/handle-checks-null.sls parse-keyword 2>&1 | %FileCheck %s --check-prefix=PARSE-KEYWORD
// RUN: %scheme-mlir %S/handle-checks-null.sls parse-attribute 2>&1 | %FileCheck %s --check-prefix=PARSE-ATTRIBUTE
// RUN: %scheme-mlir %S/handle-checks-null.sls print-string 2>&1 | %FileCheck %s --check-prefix=PRINT-STRING
// RUN: %scheme-mlir %S/handle-checks-null.sls asm-print-type 2>&1 | %FileCheck %s --check-prefix=ASM-PRINT-TYPE
// RUN: %scheme-mlir %S/handle-checks-null.sls print-operand 2>&1 | %FileCheck %s --check-prefix=PRINT-OPERAND
// RUN: %scheme-mlir %S/handle-checks-null.sls run-null 2>&1 | %FileCheck %s --check-prefix=RUN-NULL
// RUN: %scheme-mlir %S/handle-checks-null.sls add-pass-null 2>&1 | %FileCheck %s --check-prefix=ADD-PASS
// RUN: %scheme-mlir %S/handle-checks-null.sls arith-add-null 2>&1 | %FileCheck %s --check-prefix=ARITH-ADD
// RUN: %scheme-mlir %S/handle-checks-null.sls scf-forop-null 2>&1 | %FileCheck %s --check-prefix=SCF-NULL

// PARSE-OPERAND: mlir::OpAsmParser::parseOperand: parser pointer is null
// PARSE-COLON: mlir::OpAsmParser::parseColon: parser pointer is null
// PARSE-KEYWORD: mlir::OpAsmParser::parseKeyword: parser pointer is null
// PARSE-ATTRIBUTE: mlir::OpAsmParser::parseAttribute: parser pointer is null
// PRINT-STRING: mlir::OpAsmPrinter::printString: printer pointer is null
// ASM-PRINT-TYPE: mlir::AsmPrinter::printType: printer pointer is null
// PRINT-OPERAND: mlir::OpAsmPrinter::printOperand: value pointer is null
// RUN-NULL: mlir::PassManager::run!: module pointer is null
// ADD-PASS: mlir::OpPassManager::addPass: pass manager pointer is null
// ARITH-ADD: mlir::arith::AddFOp::create: lhs pointer is null
// SCF-NULL: mlir::scf::ForOp::getBody: operation pointer is null

module {}
