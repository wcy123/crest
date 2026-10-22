#!r6rs
;; (:variadic %inputs %weights) — two named variadic groups.
;; operandSegmentSizes=[2, 3] → %inputs is a list of 2, %weights a list of 3.
;; Rewrite: test.multi_variadic → test.fused using first of each group.
(library (passes wildcard-variadic-multi)
  (export run-pass)
  (import (except (rnrs) =)
          (only (mlir IR Value) mlir::Value::getType)
          (passes wildcard-common)
          (crest))

  (define-rewrite-pattern (%%multi-variadic op rewriter)
    :if-match
      %out = test.multi_variadic ((:variadic %inputs %weights))
    :then-let
      ([%a (car %inputs)]
       [%b (car %weights)]
       [!out-type (mlir::Value::getType %out)])
    :rewrite %out :with
      result = test.fused (%a %b) -> !out-type)

  (define run-pass (make-run-pass "test.multi_variadic" %%multi-variadic))

  ) ;; end library
