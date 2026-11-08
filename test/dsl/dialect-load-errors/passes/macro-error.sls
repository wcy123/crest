#!r6rs
;; The library does not expand: the :assembly-format names a variable the op does not have.
(library (passes macro-error)
  (export bad)
  (import (except (chezscheme) =) (crest dialect) (mlir IR Value))
  (define-dialect bad
    (define-op op
      :operands ((a mlir::Value?))
      :assembly-format "$a $nope attr-dict")))
