#!r6rs
;; The dialect is defined but not exported, so nothing is bound to its name after the import.
(library (passes not-exported)
  (export)
  (import (except (chezscheme) =) (crest dialect) (mlir IR Value))
  (define-dialect bad
    (define-op op :operands ((a mlir::Value?)))))
