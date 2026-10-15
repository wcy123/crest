#!r6rs
;; Two distinct ops each have a %_ operand.  The two wildcards must NOT be
;; treated as a shared value (diamond false-positive).  Pattern must fire
;; even when the two %_ operands come from different SSA values.
;;
;;   test.add(%x, %ignored_a)   →  test.fused(%x, %y)
;;   test.sub(%y, %ignored_b)   (different values for the two wildcards)
(library (passes wildcard-no-diamond-operand)
  (export run-pass)
  (import (except (rnrs) =)
          (only (mlir IR Value) mlir::Value::getType)
          (passes wildcard-common)
          (crest))

  (define-rewrite-pattern (%%no-diamond-operand op rewriter)
    :if-match
      %left  = test.add (%x %_)
      %right = test.sub (%y %_)
      %out   = test.combine (%left %right)
    :rewrite %out :with
      (%result = test.fused (%x %y) -> (mlir::Value::getType %out)))

  (define run-pass (make-run-pass "test.combine" %%no-diamond-operand))

  ) ;; end library
