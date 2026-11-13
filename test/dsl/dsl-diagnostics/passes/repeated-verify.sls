#!r6rs
;; define-op with the clause :verify twice.
(library (passes repeated-verify)
  (export verdialect)
  (import (rnrs)
          (crest dialect))

  (define-dialect verdialect
    (define-op thing
      (:verify (op) #t)
      (:verify (op) #f))))
