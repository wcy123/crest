#!r6rs
;; Ops with one optional or one variadic operand, and no operandSegmentSizes attribute.
(library (passes oo)
  (export oo)
  (import (except (chezscheme) =)
          (crest dialect)
          (mlir IR Value))

  (define-dialect oo
    (define-op maybe
      :operands ((first mlir::Value?) (second mlir::Value? :optional)))
    (define-op many
      :operands ((head mlir::Value?) (rest mlir::Value? :variadic)))))
