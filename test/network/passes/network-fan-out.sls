#!r6rs
;; Fan-out topology: one value used by both operands of the root op.
;;
;;   %a ──► test.mul ──► %shared ──► test.add(%shared, %shared)
;;
;; :check-eq verifies both operands of test.add are the same SSA value.
(library (passes network-fan-out)
  (export run-pass)
  (import (except (rnrs) =)
          (only (mlir IR Value) mlir::Value::getType)
          (passes network-common)
          (crest))

  (define-rewrite-pattern (%%fan-out op rewriter)
    :if-match
      %shared = test.mul (%a)
      %out    = test.add (%shared %shared)
    :rewrite %out :with
      (%result = test.square (%shared) -> (mlir::Value::getType %out)))

  (define run-pass (make-run-pass "test.add" %%fan-out))

  ) ;; end library
