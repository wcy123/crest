#!r6rs
;; A pass library that exports no run-pass: --crest-pass=passes= calls run-pass once the libraries are imported.
(library (passes no-run-pass)
  (export helper)
  (import (rnrs))

  (define (helper module-op) module-op))
