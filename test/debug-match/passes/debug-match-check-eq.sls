#!r6rs
;; Test pass: exercises DAG-diamond eqv? check in :bind-operands.
;; Pattern expects both operands of test.mul to be the same SSA value.
(library (passes debug-match-check-eq)
  (export run-pass)
  (import (except (rnrs) =)
          (only (mlir IR Value) mlir::Value::getType)
          (passes debug-match-common)
          (crest))

  (define-rewrite-pattern (%%check-eq-same-value op rewriter)
    :if-match
      %out = test.mul (%shared %shared)
    :then-let
      ([!out-type (mlir::Value::getType %out)])
    :rewrite %out :with
      result = test.mul (%shared %shared) -> !out-type)

  (define run-pass (make-run-pass "test.mul" %%check-eq-same-value))

  ) ;; end library
