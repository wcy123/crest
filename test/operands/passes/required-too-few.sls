#!r6rs
;; Negative: pattern expects 3 required operands, op has only 2.
;; BUG (before fix): :bind-operand at index 2 accesses out of bounds → crash/UB.
;; Expected (after fix): :bind-operands FAILED: with source location.
(library (passes required-too-few)
  (export run-pass)
  (import (except (rnrs) =)
          (only (mlir IR Value) mlir::Value::getType)
          (passes operands-common)
          (crest))

  (define-rewrite-pattern (%%match op rewriter)
    :if-match
      %out = test.add (%a %b %c)
    :rewrite %out :with
      (%result = test.fused (%a %b %c) -> (mlir::Value::getType %out)))

  (define run-pass (make-run-pass "test.add" %%match))

  ) ;; end library
