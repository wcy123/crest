#!r6rs
;; Optional operand between two required operands.
;; Pattern fires regardless of whether %b is present or absent.
(library (passes optional-middle)
  (export pass-entry-point)
  (import (except (rnrs) =)
          (only (mlir IR Value) mlir::Value::getType)
          (passes operands-common)
          (crest))

  (define-rewrite-pattern (%%match op rewriter)
    :if-match
      %out = test.add (%a (:optional %b) %c)
    :then-let
      ([!out-type (mlir::Value::getType %out)])
    :rewrite %out :with
      result = test.fused (%a %c) -> !out-type) ;

  (define-pass-entry-point (module-op) ((make-pass-body "test.add" %%match) module-op))

  ) ;; end library
