;; Bridges lib/Crest/Dialect.h — CrestDialect FFI
(library (crest dialect ffi)
  (export %crest::register-dialect!
          %crest::register-dynamic-op!)
  (import (chezscheme))

  ;; (uptr ctx) (string name) (uptr scheme-vector/12) → void
  (define %crest::register-dialect!
    (foreign-procedure "crest::register-dialect!" (uptr string uptr) void))

  ;; (uptr dialect) (string op-name) (uptr scheme-vector/7) → void
  (define %crest::register-dynamic-op!
    (foreign-procedure "crest::register-dynamic-op!" (uptr string uptr) void)))
