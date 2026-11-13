#!r6rs
;; A pass library that fails to expand: it references an unbound name.
(library (passes broken)
  (export pass-entry-point)
  (import (only (crest pass) define-pass-entry-point)
          (rnrs))

  (define-pass-entry-point (module-op)
    (this-name-is-not-bound module-op)))
