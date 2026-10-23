#!r6rs
;; Mirrors mlir/IR/OpImplementation.h
(library (mlir IR OpImplementation)
  (export mlir::OpAsmPrinter::printString
          mlir::OpAsmPrinter::printOperands
          mlir::OpAsmPrinter::printOperand
          mlir::OpAsmPrinter::printAttribute
          mlir::OpAsmPrinter::printType
          mlir::OpAsmPrinter::printOptionalAttrDict
          mlir::OpAsmPrinter::printOptionalAttrDictExcept
          mlir::OpAsmPrinter::printFunctionalType
          mlir::OpAsmPrinter::printResultTypes
          mlir::OpAsmPrinter::printSymbolName
          mlir::StringAttr::getValue)
  (import (rnrs)
          (mlir IR OpImplementation ffi))

  (define mlir::OpAsmPrinter::printString
    %mlir::OpAsmPrinter::printString)

  (define mlir::OpAsmPrinter::printOperands
    %mlir::OpAsmPrinter::printOperands)

  (define mlir::OpAsmPrinter::printOperand
    %mlir::OpAsmPrinter::printOperand)

  (define mlir::OpAsmPrinter::printAttribute
    %mlir::OpAsmPrinter::printAttribute)

  (define mlir::OpAsmPrinter::printType
    %mlir::OpAsmPrinter::printType)

  (define mlir::OpAsmPrinter::printOptionalAttrDict
    %mlir::OpAsmPrinter::printOptionalAttrDict)

  (define mlir::OpAsmPrinter::printOptionalAttrDictExcept
    %mlir::OpAsmPrinter::printOptionalAttrDictExcept)

  (define mlir::OpAsmPrinter::printFunctionalType
    %mlir::OpAsmPrinter::printFunctionalType)

  (define mlir::OpAsmPrinter::printResultTypes
    %mlir::OpAsmPrinter::printResultTypes)

  (define mlir::OpAsmPrinter::printSymbolName
    %mlir::OpAsmPrinter::printSymbolName)

  (define mlir::StringAttr::getValue
    %mlir::StringAttr::getValue)

  ) ;; end library (mlir IR OpImplementation)
