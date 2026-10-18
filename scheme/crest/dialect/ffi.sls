;; Bridges lib/Crest/Dialect.h — CrestDialect FFI
(library (crest dialect ffi)
  (export %crest::register-dialect!)
  (import (chezscheme))

  ;; (uptr ctx) (uptr name-cstr) (uptr vector/12-callbacks) → void
  (define %crest::register-dialect!
    (foreign-procedure "crest::register-dialect!" (uptr uptr uptr) void)))
