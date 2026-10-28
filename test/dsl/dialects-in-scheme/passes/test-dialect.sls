#!r6rs
;; Minimal Scheme-defined dialect used by dialects-in-scheme.mlir.
;; Exports register-dialects per the dialects-in-scheme= convention.
(library (passes test-dialect)
  (export register-dialects)
  (import (chezscheme)
          (crest dialect))

  (define-dialect testd
    (define-op noop
      :summary "no-op test op"))

  (define (register-dialects ctx)
    (testd:register! ctx)
    #t))
