#!r6rs
;; Third pass — runs after an intervening MLIR canonicalize pass.
(library (passes pass-c)
  (export pass-entry-point)
  (import (only (crest pass) define-pass-entry-point)
          (chezscheme)
          (mlir IR Operation))

  (define-pass-entry-point (module)
    (display "pass-c: running") (newline)
    module))
