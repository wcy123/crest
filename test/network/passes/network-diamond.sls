#!r6rs
;; Diamond topology: %shared feeds both test.add and test.sub,
;; both results feed test.combine.
;;
;;   %shared ──► test.add ──► %left ──┐
;;                                    ├──► test.combine ──► %out
;;   %shared ──► test.sub ──► %right ─┘
;;
;; :check-eq verifies the same %shared SSA value appears in both paths.
(library (passes network-diamond)
  (export run-pass)
  (import (except (rnrs) =)
          (only (mlir IR Value) mlir::Value::getType)
          (passes network-common)
          (crest))

  (define-rewrite-pattern (%%diamond op rewriter)
    :if-match
      %left  = test.add     (%shared %x)
      %right = test.sub     (%shared %y)
      %out   = test.combine (%left %right)
    :then-let
      ([!out-type (mlir::Value::getType %out)])
    :rewrite %out :with
      result = test.fused (%shared %x %y) -> !out-type)

  (define run-pass (make-run-pass "test.combine" %%diamond))

  ) ;; end library
