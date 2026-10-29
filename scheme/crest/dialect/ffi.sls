;; Bridges lib/Crest/Dialect.h — CrestDialect FFI
(library (crest dialect ffi)
  (export %crest::load-scheme-dialect!
          %crest::register-dynamic-op!
          %mlir::OperationName::getStringRef)
  (import (chezscheme))

  ;; (uptr ctx) (string dialect-name) (string module-name) → void
  ;; Loads a Scheme-defined dialect into an existing MLIRContext.
  ;; Must be called when multiThreadedExecutionContext == 0.
  (define %crest::load-scheme-dialect!
    (foreign-procedure "crest::load-scheme-dialect!" (uptr string string) void))

  ;; (uptr dialect) (string op-name) (scheme-object vector/7) → void
  (define %crest::register-dynamic-op!
    (foreign-procedure "crest::register-dynamic-op!" (uptr string scheme-object) void))

  ;; (uptr op-name) → string — get fully-qualified name of an OperationName.
  (define %mlir::OperationName::getStringRef
    (foreign-procedure "mlir::OperationName::getStringRef" (uptr) string)))
