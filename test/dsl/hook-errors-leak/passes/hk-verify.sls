#!r6rs
;; A Scheme dialect whose attribute verifier raises an error.
(library (passes hk-verify)
  (export hkv)
  (import (except (chezscheme) =)
          (crest dialect))

  (define-dialect hkv
    (:verify-op-attr (op attr)
      (error 'verify-op-attr "the attribute is broken"))
    (define-op raises)))
