#!r6rs
;; Third pass — runs after an intervening MLIR canonicalize pass.
(library (passes pass-c)
  (export run-pass)
  (import (chezscheme)
          (mlir IR Operation))

  (define (run-pass module)
    (display "pass-c: running") (newline)
    module))
