#!r6rs
;; define-op with the clause :operands twice.
(library (passes repeated-operands)
  (export repdialect)
  (import (rnrs)
          (only (mlir IR Value) mlir::Value?)
          (crest dialect))

  (define-dialect repdialect
    (define-op thing
      :operands ((a mlir::Value?))
      :operands ((b mlir::Value?)))))
