#!r6rs
;; A Scheme dialect whose :initialize clause raises an error.
(library (passes hk-init)
  (export hki)
  (import (except (chezscheme) =)
          (crest dialect))

  (define-dialect hki
    (:initialize (dialect)
      (error 'initialize "initialize failed"))
    (define-op noop)))
