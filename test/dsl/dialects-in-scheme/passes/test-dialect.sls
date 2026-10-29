#!r6rs
;; Minimal Scheme-defined dialect used by dialects-in-scheme.mlir.
;; define-dialect auto-generates testd:dialect-callbacks, which is retrieved
;; by the new CrestDialect 4-arg constructor via scheme_call("testd:dialect-callbacks").
(library (passes test-dialect)
  (export testd:dialect-callbacks)
  (import (chezscheme)
          (crest dialect))

  (define-dialect testd
    (define-op noop
      :summary "no-op test op")))
