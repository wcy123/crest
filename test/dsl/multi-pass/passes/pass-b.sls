#!r6rs
;; Second pass in a multi-pass pipeline.
;; Imports pass-a and calls its helper, then prints its own line.
(library (passes pass-b)
  (export run-pass)
  (import (chezscheme)
          (passes pass-a)
          (mlir IR Operation))

  (define (run-pass module)
    (pass-a:annotate! module)
    (display "pass-b: running") (newline)
    module))
