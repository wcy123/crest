;; Bridges lib/Crest/Dialect.h — CrestDialect FFI
(library (crest dialect ffi)
  (export %crest::load-scheme-dialect!
          %crest::register-dynamic-op!
          %crest::register-dynamic-type!
          %crest::DynamicType::get
          %crest::DynamicType::isa
          %crest::DynamicType::getParams
          %crest::CrestDialect::loadDependentDialect
          %crest::Fold::addValue
          %crest::Fold::addAttribute
          %crest::DynamicType::addParam
          %crest::DynamicType::setMessage
          %mlir::OperationName::getStringRef)
  (import (chezscheme)
          (crest support foreign))

  ;; (uptr ctx) (string dialect-name) (string module-name) → void
  ;; Loads a Scheme-defined dialect into an existing MLIRContext.
  ;; Must be called when multiThreadedExecutionContext == 0.
  (define %crest::load-scheme-dialect!
    (crest-foreign-procedure "crest::load-scheme-dialect!" (uptr string string) void))

  ;; (uptr dialect) (string op-name) (scheme-object vector/8) (scheme-object interfaces) → void
  ;; slots: the entry points of verify, verify-regions, parse, print, fold,
  ;; get-canonicalization-patterns, populate-default-attrs, then the list of traits;
  ;; interfaces: the list of (TypeID . dispatcher) pairs of the op's :interfaces entries
  ;; (see lib/Crest/Op.cpp)
  (define %crest::register-dynamic-op!
    (crest-foreign-procedure "crest::register-dynamic-op!" (uptr string scheme-object scheme-object)
                             void))

  ;; (uptr dialect) (string type-name) (scheme-object vector/3) → void
  ;; slots: the entry points of verify, parse, print (see lib/Crest/Type.cpp)
  (define %crest::register-dynamic-type!
    (crest-foreign-procedure "crest::register-dynamic-type!" (uptr string scheme-object) void))

  ;; (string dialect) (string type-name) (scheme-object attributes) (uptr ctx) → uptr (0 on failure)
  (define %crest::DynamicType::get
    (crest-foreign-procedure "crest::DynamicType::get" (string string scheme-object uptr) uptr))

  ;; (string dialect) (string type-name) (uptr type) → int
  (define %crest::DynamicType::isa
    (crest-foreign-procedure "crest::DynamicType::isa" (string string uptr) int))

  ;; (uptr type) → list of attribute pointers
  (define %crest::DynamicType::getParams
    (crest-foreign-procedure "crest::DynamicType::getParams" (uptr) scheme-object))

  ;; (uptr dialect) (string name) → void — load the dialect `name` before `dialect`; no such dialect
  ;; in the registry is a fatal error.
  (define %crest::CrestDialect::loadDependentDialect
    (crest-foreign-procedure "crest::CrestDialect::loadDependentDialect" (uptr string) void))

  ;; (uptr folded) (uptr value) → void, (uptr folded) (uptr attribute) → void — a result of a fold.
  (define %crest::Fold::addValue
    (crest-foreign-procedure "crest::Fold::addValue" (uptr uptr) void))
  (define %crest::Fold::addAttribute
    (crest-foreign-procedure "crest::Fold::addAttribute" (uptr uptr) void))

  ;; (uptr sink) (uptr attribute) → void — a parameter that the parser of a dialect type parsed;
  ;; (uptr sink) (string message) → void — why a verifier or parser of a dialect type failed.
  (define %crest::DynamicType::addParam
    (crest-foreign-procedure "crest::DynamicType::addParam" (uptr uptr) void))
  (define %crest::DynamicType::setMessage
    (crest-foreign-procedure "crest::DynamicType::setMessage" (uptr string) void))

  ;; (uptr op-name) → string — get fully-qualified name of an OperationName.
  (define %mlir::OperationName::getStringRef
    (crest-foreign-procedure "mlir::OperationName::getStringRef" (uptr) string)))
