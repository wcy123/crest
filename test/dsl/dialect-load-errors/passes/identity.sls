#!r6rs
(library (passes identity)
  (export run-pass)
  (import (rnrs))

  (define (run-pass module-op) module-op))
