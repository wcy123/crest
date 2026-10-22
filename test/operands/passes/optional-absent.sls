#!r6rs
;; Positive: pattern has optional operand, op does NOT provide it.
;; The :where uses unbound-value? to detect absence and rewrite differently.
(library (passes optional-absent)
  (export run-pass)
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

  (define run-pass (make-run-pass "test.add" %%match))

  ) ;; end library
