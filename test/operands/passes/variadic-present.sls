#!r6rs
;; Variadic operand at end — fires only when variadic group is non-empty.
;; %b binds to a list of values; rewrite uses only %a for simplicity.
(library (passes variadic-present)
  (export run-pass)
  (import (except (rnrs) =)
          (only (mlir IR Value) mlir::Value::getType)
          (passes operands-common)
          (crest))

  (define-rewrite-pattern (%%match op rewriter)
    :if-match
      %out = test.add (%a (:variadic %b))
        :where (not (unbound-value? %b))
    :rewrite %out :with
      (%result = test.fused (%a) -> (mlir::Value::getType %out)))

  (define run-pass (make-run-pass "test.add" %%match))

  ) ;; end library
