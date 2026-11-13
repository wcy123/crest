#!r6rs
;; Positive: pattern expects 2 required operands, op has exactly 2.
(library (passes required-exact)
  (export pass-entry-point)
  (import (except (rnrs) =)
          (only (mlir IR Value) mlir::Value::getType)
          (passes operands-common)
          (crest))

  (define-rewrite-pattern (%%match op rewriter)
    :if-match
      %out = test.add (%a %b)
    :then-let
      ([!out-type (mlir::Value::getType %out)])
    :rewrite %out :with
      result = test.fused (%a %b) -> !out-type) ;

  (define-pass-entry-point (module-op) ((make-pass-body "test.add" %%match) module-op))

  ) ;; end library
