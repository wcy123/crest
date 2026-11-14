#!r6rs
;; A Scheme dialect named "simple" with one op. passes/simple.sls and passes/simple2.sls are two libraries
;; for the same dialect name.
(library (passes simple2)
  (export simple)
  (import (chezscheme)
          (crest dialect))

  (define-dialect simple
    (define-op thing
      :summary "an op")))
