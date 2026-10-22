#!r6rs
;; Two optional operands — fires only when first is absent, second is present.
(library (passes two-optionals-first-absent)
  (export run-pass)
  (import (except (rnrs) =)
          (only (mlir IR Value) mlir::Value::getType)
          (passes operands-common)
          (crest))

  (define-rewrite-pattern (%%match op rewriter)
    :if-match
      %out = test.add ((:optional %a) (:optional %b))
        :where (and (unbound-value? %a) (not (unbound-value? %b)))
    :then-let
      ([!out-type (mlir::Value::getType %out)])
    :rewrite %out :with
      result = test.fused (%b) -> !out-type) ;

  (define run-pass (make-run-pass "test.add" %%match))

  ) ;; end library
