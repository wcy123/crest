#!r6rs
;; A Scheme dialect with a type of its own: dt.pair<T, U>, printed `!dt.pair<i32, f32>`.
(library (passes type-dialect)
  (export dt)
  (import (except (chezscheme) =)
          (crest dialect)
          (mlir IR Value)
          (mlir IR BuiltinAttributes)
          (mlir IR OpImplementation))

  ;; Some parser bindings answer a boolean, some an integer (0 = failure).
  (define (%%ok? x) (and x (not (eqv? x 0))))

  ;; The type parameters are attributes: here one TypeAttr per element.
  (define (%%parse-element parser)
    (let ([type (mlir::OpAsmParser::parseType parser)])
      (and (%%ok? type) (mlir::TypeAttr::get type))))

  (define-dialect dt
    (define-type pair
      (:verify (params)
        (or (and (eqv? (length params) 2)
                 (not (equal? (car params) (cadr params))))
            "a pair has two different element types"))
      (:parse (parser)
        (and (mlir::OpAsmParser::parseLess parser)
             (let ([first (%%parse-element parser)])
               (and first
                    (mlir::OpAsmParser::parseComma parser)
                    (let ([second (%%parse-element parser)])
                      (and second
                           (mlir::OpAsmParser::parseGreater parser)
                           (list first second)))))))
      (:print (printer params)
        (mlir::OpAsmPrinter::printString printer "<")
        (mlir::OpAsmPrinter::printType printer (mlir::TypeAttr::getValue (car params)))
        (mlir::OpAsmPrinter::printString printer ", ")
        (mlir::OpAsmPrinter::printType printer (mlir::TypeAttr::getValue (cadr params)))
        (mlir::OpAsmPrinter::printString printer ">")))
    (define-op make
      :operands ((a mlir::Value?) (b mlir::Value?))
      :results  ((out dt.pair?)))))
