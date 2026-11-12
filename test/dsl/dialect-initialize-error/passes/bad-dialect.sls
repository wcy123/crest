#!r6rs
;; A Scheme dialect whose :initialize clause raises an error.
(library (passes bad-dialect)
  (export badd)
  (import (except (chezscheme) =)
          (crest dialect)
          (mlir IR Value))

  (define-dialect badd
    (:initialize (dialect)
      (error 'badd "initialize failed"))
    (define-op ping
      :operands ((a mlir::Value?))
      :results  ((out mlir::Value?)))))
