#!r6rs
;; Variadic operand at end — fires only when variadic group is non-empty.
;; %b binds to a list of values; rewrite uses only %a for simplicity.
(library (passes variadic-present)
  (export pass-entry-point)
  (import (except (rnrs) =)
          (only (mlir IR Value) mlir::Value::getType)
          (passes operands-common)
          (crest))

  (define-rewrite-pattern (%%match op rewriter)
    :if-match
      %out = test.add (%a (:variadic %b))
        :where (not (unbound-value? %b))
    :then-let
      ([!out-type (mlir::Value::getType %out)])
    :rewrite %out :with
      result = test.fused (%a) -> !out-type) ;

  (define-pass-entry-point (module-op) ((make-pass-body "test.add" %%match) module-op))

  ) ;; end library
