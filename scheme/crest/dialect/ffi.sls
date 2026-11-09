;; Bridges lib/Crest/Dialect.h — CrestDialect FFI
(library (crest dialect ffi)
  (export %crest::load-scheme-dialect!
          %crest::register-dynamic-op!
          %crest::register-dynamic-type!
          %crest::DynamicType::get
          %crest::DynamicType::isa
          %crest::DynamicType::getParams
          %crest::CrestDialect::loadDependentDialect
          %crest::CrestDialect::reportFailure
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

  ;; (uptr dialect) (string type-name) (scheme-object vector/3) → void
  ;; slots: verify, parse, print (see lib/Crest/Type.cpp)
  (define %crest::register-dynamic-type!
    (foreign-procedure "crest::register-dynamic-type!" (uptr string scheme-object) void))

  ;; (string dialect) (string type-name) (scheme-object attributes) (uptr ctx) → uptr (0 on failure)
  (define %crest::DynamicType::get
    (foreign-procedure "crest::DynamicType::get" (string string scheme-object uptr) uptr))

  ;; (string dialect) (string type-name) (uptr type) → int
  (define %crest::DynamicType::isa
    (foreign-procedure "crest::DynamicType::isa" (string string uptr) int))

  ;; (uptr type) → list of attribute pointers
  (define %crest::DynamicType::getParams
    (foreign-procedure "crest::DynamicType::getParams" (uptr) scheme-object))

  ;; (uptr dialect) (string name) → void — load the dialect `name` before `dialect`; no such dialect
  ;; in the registry is a fatal error.
  (define %crest::CrestDialect::loadDependentDialect
    (foreign-procedure "crest::CrestDialect::loadDependentDialect" (uptr string) void))

  ;; (string message) → void — the text of an error that a verifier of the dialect raised, for the
  ;; diagnostic of its failure.
  (define %crest::CrestDialect::reportFailure
    (foreign-procedure "crest::CrestDialect::reportFailure" (string) void))

  ;; (uptr op-name) → string — get fully-qualified name of an OperationName.
  (define %mlir::OperationName::getStringRef
    (foreign-procedure "mlir::OperationName::getStringRef" (uptr) string)))
