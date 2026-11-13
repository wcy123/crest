#!r6rs
;; Second pass in a multi-pass pipeline.
;; Imports pass-a and calls its helper, then prints its own line.
(library (passes pass-b)
  (export pass-entry-point)
  (import (only (crest pass) define-pass-entry-point)
          (chezscheme)
          (passes pass-a)
          (mlir IR Operation))

  (define-pass-entry-point (module)
    (pass-a:annotate! module)
    (display "pass-b: running") (newline)
    module))
