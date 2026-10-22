#!r6rs
;; Two distinct ops each produce a _ result.  The two wildcards must NOT be
;; treated as the same SSA value (diamond false-positive on results).
;;
;;   (_ %a) = test.split_a(%x)   — discard result 0 of split_a
;;   (_ %b) = test.split_b(%y)   — discard result 0 of split_b (different value)
;;   %out    = test.combine(%a %b)
(library (passes wildcard-no-diamond-result)
  (export run-pass)
  (import (except (rnrs) =)
          (only (mlir IR Value) mlir::Value::getType)
          (passes wildcard-common)
          (crest))

  (define-rewrite-pattern (%%no-diamond-result op rewriter)
    :if-match
      (_ %a) = test.split_a (%x)
      (_ %b) = test.split_b (%y)
      %out    = test.combine  (%a %b)
    :then-let
      ([!out-type (mlir::Value::getType %out)])
    :rewrite %out :with
      result = test.fused (%x %y) -> !out-type)

  (define run-pass (make-run-pass "test.combine" %%no-diamond-result))

  ) ;; end library
