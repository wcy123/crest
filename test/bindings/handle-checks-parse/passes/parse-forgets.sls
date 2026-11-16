#!r6rs
;; A dialect whose op parses two operands and a type, and does not look at what the parse bindings return.
;; With one operand in the text, parseOperandList fails and returns 0, and resolveOperands is given the 0.
(library (passes parse-forgets)
  (export pforgets)
  (import (except (rnrs) =)
          (crest dialect)
          (mlir IR Value)
          (mlir IR OpImplementation))

  (define-dialect pforgets
    (define-op op
      :operands ((lhs mlir::Value?) (rhs mlir::Value?))
      (:parse (parser state)
        (let* ([ops  (mlir::OpAsmParser::parseOperandList parser 2)]
               [type (mlir::OpAsmParser::parseColonType parser)])
          (mlir::OpAsmParser::resolveOperands parser ops type state))))))
