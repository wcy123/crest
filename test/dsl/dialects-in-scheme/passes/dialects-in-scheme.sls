#!r6rs
;; Pass for dialects-in-scheme.mlir.
;; Verifies that dialects-in-scheme= registered the testd dialect in the
;; MLIRContext before runOnOperation() by querying getOrLoadDialect.
(library (passes dialects-in-scheme)
  (export run-pass)
  (import (chezscheme)
          (mlir IR Operation)
          (mlir IR MLIRContext))

  (define (run-pass module)
    (let* ([ctx    (mlir::Operation::getContext module)]
           [loaded (mlir::MLIRContext::getOrLoadDialect ctx "testd")])
      (if (not (zero? loaded))
          (begin (display "dialect-loaded: testd") (newline))
          (begin (display "dialect-not-loaded: testd") (newline))))
    module))
