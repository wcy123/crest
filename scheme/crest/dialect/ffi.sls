;; Bridges lib/Crest/Dialect.h — CrestDialect FFI
(library (crest dialect ffi)
  (export %crest::register-dialect!)
  (import (chezscheme))

  ;; (uptr ctx) (string name) (uptr scheme-vector/12) → void
  (define %crest::register-dialect!
    (foreign-procedure "crest::register-dialect!" (uptr string uptr) void)))
