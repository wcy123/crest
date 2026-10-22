#!r6rs
;; _ inside (:optional _) — match the optional slot without binding it.
;; Two (:optional _) in different ops must not collide.
;;
;; Pattern: test.op(%x, (:optional _), %y) → test.fused(%x, %y)
;; Fires for both the 2-operand form (optional absent) and
;; the 3-operand form (optional present, value irrelevant).
(library (passes wildcard-optional)
  (export run-pass)
  (import (except (rnrs) =)
          (only (mlir IR Value) mlir::Value::getType)
          (passes wildcard-common)
          (crest))

  (define-rewrite-pattern (%%wildcard-optional op rewriter)
    :if-match
      %out = test.op (%x (:optional _) %y)
    :then-let
      ([!out-type (mlir::Value::getType %out)])
    :rewrite %out :with
      result = test.fused (%x %y) -> !out-type)

  (define run-pass (make-run-pass "test.op" %%wildcard-optional))

  ) ;; end library
