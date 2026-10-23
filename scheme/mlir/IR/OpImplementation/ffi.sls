#!r6rs
;; Mirrors mlir/IR/OpImplementation.h
(library (mlir IR OpImplementation ffi)
  (export %mlir::OpAsmPrinter::printString
          %mlir::OpAsmPrinter::printOperands
          %mlir::OpAsmPrinter::printOperand
          %mlir::OpAsmPrinter::printAttribute
          %mlir::OpAsmPrinter::printType
          %mlir::OpAsmPrinter::printOptionalAttrDict
          %mlir::OpAsmPrinter::printOptionalAttrDictExcept
          %mlir::OpAsmPrinter::printFunctionalType
          %mlir::OpAsmPrinter::printResultTypes
          %mlir::OpAsmPrinter::printSymbolName
          %mlir::StringAttr::getValue
          %mlir::TypeAttr::getValue
          %mlir::FunctionType::getNumInputs
          %mlir::FunctionType::getInput
          %mlir::FunctionType::getNumResults
          %mlir::FunctionType::getResult
          %mlir::OpAsmPrinter::printRegion
          ;; Parser bindings
          %mlir::OpAsmParser::parseOperandList
          %mlir::OpAsmParser::parseOperand
          %mlir::OpAsmParser::parseOptionalOperand
          %mlir::OpAsmParser::resolveOperands
          %mlir::OpAsmParser::resolveOperandsFunctional
          %mlir::OpAsmParser::parseColonType
          %mlir::OpAsmParser::parseType
          %mlir::OpAsmParser::parseFunctionalType
          %mlir::OpAsmParser::parseOptionalAttrDict
          %mlir::OpAsmParser::parseAttribute
          %mlir::OpAsmParser::parseKeyword
          %mlir::OpAsmParser::parseLParen
          %mlir::OpAsmParser::parseRParen
          %mlir::OpAsmParser::parseColon
          %mlir::OpAsmParser::parseComma
          %mlir::OpAsmParser::parseArrow
          %mlir::OpAsmParser::parseSymbolName
          %mlir::isa<FunctionType>
          %mlir::OperationState::addType)
  (import (chezscheme))

  (define %mlir::OpAsmPrinter::printString
    (foreign-procedure "mlir::OpAsmPrinter::printString" (uptr string) void))

  (define %mlir::OpAsmPrinter::printOperands
    (foreign-procedure "mlir::OpAsmPrinter::printOperands" (uptr uptr) void))

  (define %mlir::OpAsmPrinter::printOperand
    (foreign-procedure "mlir::OpAsmPrinter::printOperand" (uptr uptr) void))

  (define %mlir::OpAsmPrinter::printAttribute
    (foreign-procedure "mlir::OpAsmPrinter::printAttribute" (uptr uptr) void))

  (define %mlir::OpAsmPrinter::printType
    (foreign-procedure "mlir::OpAsmPrinter::printType" (uptr uptr) void))

  ;; Print optional attr dict with no elision.
  (define %mlir::OpAsmPrinter::printOptionalAttrDict
    (foreign-procedure "mlir::OpAsmPrinter::printOptionalAttrDict" (uptr uptr) void))

  ;; Print optional attr dict excluding a single named attribute.
  (define %mlir::OpAsmPrinter::printOptionalAttrDictExcept
    (foreign-procedure "mlir::OpAsmPrinter::printOptionalAttrDictExcept" (uptr uptr string) void))

  (define %mlir::OpAsmPrinter::printFunctionalType
    (foreign-procedure "mlir::OpAsmPrinter::printFunctionalType" (uptr uptr) void))

  (define %mlir::OpAsmPrinter::printResultTypes
    (foreign-procedure "mlir::OpAsmPrinter::printResultTypes" (uptr uptr) void))

  (define %mlir::OpAsmPrinter::printSymbolName
    (foreign-procedure "mlir::OpAsmPrinter::printSymbolName" (uptr string) void))

  (define %mlir::StringAttr::getValue
    (foreign-procedure "mlir::StringAttr::getValue" (uptr) string))

  (define %mlir::TypeAttr::getValue
    (foreign-procedure "mlir::TypeAttr::getValue" (uptr) uptr))

  (define %mlir::FunctionType::getNumInputs
    (foreign-procedure "mlir::FunctionType::getNumInputs" (uptr) uptr))

  (define %mlir::FunctionType::getInput
    (foreign-procedure "mlir::FunctionType::getInput" (uptr uptr) uptr))

  (define %mlir::FunctionType::getNumResults
    (foreign-procedure "mlir::FunctionType::getNumResults" (uptr) uptr))

  (define %mlir::FunctionType::getResult
    (foreign-procedure "mlir::FunctionType::getResult" (uptr uptr) uptr))

  (define %mlir::OpAsmPrinter::printRegion
    (foreign-procedure "mlir::OpAsmPrinter::printRegion" (uptr uptr int int) void))

  ;; ── Parser ─────────────────────────────────────────────────────────────────

  ;; Returns handle (uptr) to UnresolvedOperands or 0 on failure.
  (define %mlir::OpAsmParser::parseOperandList
    (foreign-procedure "mlir::OpAsmParser::parseOperandList" (uptr integer-64) uptr))

  (define %mlir::OpAsmParser::parseOperand
    (foreign-procedure "mlir::OpAsmParser::parseOperand" (uptr) uptr))

  (define %mlir::OpAsmParser::parseOptionalOperand
    (foreign-procedure "mlir::OpAsmParser::parseOptionalOperand" (uptr) uptr))

  (define %mlir::OpAsmParser::resolveOperands
    (foreign-procedure "mlir::OpAsmParser::resolveOperands" (uptr uptr uptr uptr) boolean))

  (define %mlir::OpAsmParser::resolveOperandsFunctional
    (foreign-procedure "mlir::OpAsmParser::resolveOperandsFunctional" (uptr uptr uptr uptr) boolean))

  (define %mlir::OpAsmParser::parseColonType
    (foreign-procedure "mlir::OpAsmParser::parseColonType" (uptr) uptr))

  (define %mlir::OpAsmParser::parseType
    (foreign-procedure "mlir::OpAsmParser::parseType" (uptr) uptr))

  (define %mlir::OpAsmParser::parseFunctionalType
    (foreign-procedure "mlir::OpAsmParser::parseFunctionalType" (uptr) uptr))

  (define %mlir::OpAsmParser::parseOptionalAttrDict
    (foreign-procedure "mlir::OpAsmParser::parseOptionalAttrDict" (uptr uptr) boolean))

  (define %mlir::OpAsmParser::parseAttribute
    (foreign-procedure "mlir::OpAsmParser::parseAttribute" (uptr uptr string) uptr))

  (define %mlir::OpAsmParser::parseKeyword
    (foreign-procedure "mlir::OpAsmParser::parseKeyword" (uptr string) boolean))

  (define %mlir::OpAsmParser::parseLParen
    (foreign-procedure "mlir::OpAsmParser::parseLParen" (uptr) boolean))

  (define %mlir::OpAsmParser::parseRParen
    (foreign-procedure "mlir::OpAsmParser::parseRParen" (uptr) boolean))

  (define %mlir::OpAsmParser::parseColon
    (foreign-procedure "mlir::OpAsmParser::parseColon" (uptr) boolean))

  (define %mlir::OpAsmParser::parseComma
    (foreign-procedure "mlir::OpAsmParser::parseComma" (uptr) boolean))

  (define %mlir::OpAsmParser::parseArrow
    (foreign-procedure "mlir::OpAsmParser::parseArrow" (uptr) boolean))

  (define %mlir::OpAsmParser::parseSymbolName
    (foreign-procedure "mlir::OpAsmParser::parseSymbolName" (uptr uptr) string))

  (define %mlir::isa<FunctionType>
    (foreign-procedure "mlir::isa<FunctionType>" (uptr) boolean))

  (define %mlir::OperationState::addType
    (foreign-procedure "mlir::OperationState::addType" (uptr uptr) void))

  ) ;; end library (mlir IR OpImplementation ffi)
