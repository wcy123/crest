#!r6rs
;; A dialect with a type of its own, dcp.pair<T, U>, whose :print-type decides how it is printed:
;; `!dcp.pair<i32 & f32>`, not the `<i32, f32>` that it parses. The printer that MLIR gives a dialect
;; is a DialectAsmPrinter, an mlir::AsmPrinter: the keyword, the nested type and attribute, and the
;; raw text through its stream.
;; Not here: :print-attribute. A Scheme dialect has no attribute of its own (there is no
;; define-attribute), so MLIR never prints one through it.
(library (passes dcbprint)
  (export dcp)
  (import (except (chezscheme) =)
          (crest dialect)
          (mlir IR Value)
          (mlir IR BuiltinAttributes)
          (mlir IR OpImplementation)
          (llvm Support raw_ostream))

  (define (%%ok? x) (and x (not (eqv? x 0))))

  (define (%%parse-element parser)
    (let ([type (mlir::OpAsmParser::parseType parser)])
      (and (%%ok? type) (mlir::TypeAttr::get type))))

  (define (%%text printer string)
    (llvm::raw_ostream::write (mlir::AsmPrinter::getStream printer) string))

  (define-dialect dcp
    (:print-type (type printer)
      (let ([params (dcp.pair-params type)])
        (mlir::AsmPrinter::printKeywordOrString printer "pair")
        (%%text printer "<")
        (mlir::AsmPrinter::printType printer (mlir::TypeAttr::getValue (car params)))
        (%%text printer " & ")
        (mlir::AsmPrinter::printAttribute printer (cadr params))
        (%%text printer ">")))
    (define-type pair
      (:parse (parser)
        (and (mlir::OpAsmParser::parseLess parser)
             (let ([first (%%parse-element parser)])
               (and first
                    (mlir::OpAsmParser::parseComma parser)
                    (let ([second (%%parse-element parser)])
                      (and second
                           (mlir::OpAsmParser::parseGreater parser)
                           (list first second)))))))
      ;; What the type would print without the :print-type of the dialect, which takes over.
      (:print (printer params)
        (mlir::OpAsmPrinter::printString printer "<")
        (mlir::OpAsmPrinter::printType printer (mlir::TypeAttr::getValue (car params)))
        (mlir::OpAsmPrinter::printString printer ", ")
        (mlir::OpAsmPrinter::printType printer (mlir::TypeAttr::getValue (cadr params)))
        (mlir::OpAsmPrinter::printString printer ">")))
    (define-op make
      :operands ((a mlir::Value?) (b mlir::Value?))
      :results  ((out dcp.pair?)))))
