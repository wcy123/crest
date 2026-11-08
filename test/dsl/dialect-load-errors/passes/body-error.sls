#!r6rs
;; The library expands, but its body raises an error when it runs. A Chez library body only runs
;; when something it exports is first used, so a plain import does not see this.
(library (passes body-error)
  (export bad)
  (import (except (chezscheme) =) (crest dialect) (mlir IR Value))
  (define boom (error 'body-error "boom at library load"))
  (define-dialect bad
    (define-op op :operands ((a mlir::Value?)))))
