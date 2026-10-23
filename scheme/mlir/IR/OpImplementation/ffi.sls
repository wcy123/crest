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
          %mlir::StringAttr::getValue)
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

  ) ;; end library (mlir IR OpImplementation ffi)
