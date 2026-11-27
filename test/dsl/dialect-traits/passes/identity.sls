#!r6rs
(library (passes identity)
  (export pass-entry-point)
  (import (only (crest define-pass) define-pass-entry-point)
          (rnrs))

  (define-pass-entry-point (module-op) module-op))
