#!r6rs
;; Minimal Scheme-defined dialect used by dialects-in-scheme.mlir.
;; define-dialect testd binds `testd` to the callbacks vector.
;; CrestDialect retrieves it via Stop_level_value("testd") after import.
(library (passes test-dialect)
  (export testd)
  (import (chezscheme)
          (crest dialect))

  (define-dialect testd
    (define-op noop
      :summary "no-op test op")))
