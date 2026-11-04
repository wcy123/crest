#!r6rs
;; A pass library that fails to expand: it references an unbound name.
(library (passes broken)
  (export run-pass)
  (import (rnrs))

  (define (run-pass module-op)
    (this-name-is-not-bound module-op)))
