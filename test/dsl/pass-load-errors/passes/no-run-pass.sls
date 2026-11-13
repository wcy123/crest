#!r6rs
;; A pass library that exports no pass-entry-point: --crest-pass=passes= calls pass-entry-point once the libraries are imported.
(library (passes no-run-pass)
  (export helper)
  (import (rnrs))

  (define (helper module-op) module-op))
