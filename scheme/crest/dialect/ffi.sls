;; Bridges lib/Crest/Dialect.h — CrestDialect FFI
(library (crest dialect ffi)
  (export %crest::register-dialect!
          %crest::register-dynamic-op!
          %mlir::OperationName::getStringRef)
  (import (chezscheme))

  ;; (uptr ctx) (string name) (scheme-object vector/12) → void
  (define %crest::register-dialect!
    (foreign-procedure "crest::register-dialect!" (uptr string scheme-object) void))

  ;; (uptr dialect) (string op-name) (scheme-object vector/7) → void
  (define %crest::register-dynamic-op!
    (foreign-procedure "crest::register-dynamic-op!" (uptr string scheme-object) void))

  ;; (uptr op-name) → string — get fully-qualified name of an OperationName.
  (define %mlir::OperationName::getStringRef
    (foreign-procedure "mlir::OperationName::getStringRef" (uptr) string))

  )
