#!r6rs
;; A Scheme dialect that asks for a dialect that is not registered.
(library (passes missingdep)
  (export missingdep)
  (import (chezscheme)
          (crest dialect))

  (define-dialect missingdep
    (:get-dependent-dialects () (list "nonexistentdialect"))
    (define-op thing
      :summary "an op")))
