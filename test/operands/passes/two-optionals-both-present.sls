#!r6rs
;; Two optional operands — fires only when both are present.
(library (passes two-optionals-both-present)
  (export pass-entry-point)
  (import (except (rnrs) =)
          (only (mlir IR Value) mlir::Value::getType)
          (passes operands-common)
          (crest))

  (define-rewrite-pattern (%%match op rewriter)
    :if-match
      %out = test.add ((:optional %a) (:optional %b))
        :where (and (not (unbound-value? %a)) (not (unbound-value? %b)))
    :then-let
      ([!out-type (mlir::Value::getType %out)])
    :rewrite %out :with
      result = test.fused (%a %b) -> !out-type) ;

  (define-pass-entry-point (module-op) ((make-pass-body "test.add" %%match) module-op))

  ) ;; end library
