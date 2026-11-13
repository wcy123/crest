#!r6rs
;; Positive: pattern has optional operand, op does NOT provide it.
;; The :where uses unbound-value? to detect absence and rewrite differently.
(library (passes optional-absent)
  (export pass-entry-point)
  (import (except (rnrs) =)
          (only (mlir IR Value) mlir::Value::getType)
          (passes operands-common)
          (crest))

  (define-rewrite-pattern (%%match op rewriter)
    :if-match
      %out = test.add (%a (:optional %b))
        :where (unbound-value? %b)
    :then-let
      ([!out-type (mlir::Value::getType %out)])
    :rewrite %out :with
      result = test.fused (%a) -> !out-type) ;

  (define-pass-entry-point (module-op) ((make-pass-body "test.add" %%match) module-op))

  ) ;; end library
