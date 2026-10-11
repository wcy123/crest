#!r6rs
;; Two optional operands — fires only when both are present.
(library (passes two-optionals-both-present)
  (export run-pass)
  (import (except (rnrs) =)
          (only (mlir IR Value) mlir::Value::getType)
          (passes operands-common)
          (crest))

  (define-rewrite-pattern (%%match op rewriter)
    :if-match
      %out = test.add ((:optional %a) (:optional %b))
        :where (and (not (unbound-value? %a)) (not (unbound-value? %b)))
    :rewrite %out :with
      (%result = test.fused (%a %b) -> (mlir::Value::getType %out)))

  (define run-pass (make-run-pass "test.add" %%match))

  ) ;; end library
