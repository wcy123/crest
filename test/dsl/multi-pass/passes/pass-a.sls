#!r6rs
;; First pass in a multi-pass pipeline.
;; Adds a marker attribute to the module and prints a line.
;; Does NOT export run-pass — it is a helper library loaded by pass-b.sls.
(library (passes pass-a)
  (export pass-a:annotate!)
  (import (chezscheme)
          (mlir IR Operation))

  (define (pass-a:annotate! module)
    (display "pass-a: running") (newline)))
