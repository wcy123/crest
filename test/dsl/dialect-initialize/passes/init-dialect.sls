#!r6rs
;; A Scheme dialect with an :initialize clause of its own, next to an op.
(library (passes init-dialect)
  (export initd)
  (import (except (chezscheme) =)
          (crest dialect)
          (mlir IR Value))

  (define-dialect initd
    (:initialize (dialect)
      (display "initd: user initialize ran")
      (newline))
    (define-op ping
      :operands ((a mlir::Value?))
      :results  ((out mlir::Value?)))))
