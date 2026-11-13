#!r6rs
;; A pass whose body raises an error.
(library (passes raises)
  (export pass-entry-point)
  (import (except (rnrs) =) (crest))

  (define-pass-entry-point (module-op)
    (error 'raises "the pass is broken")))
