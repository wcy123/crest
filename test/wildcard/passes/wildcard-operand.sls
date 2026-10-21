#!r6rs
;; _ in operand position: skip operands we don't need in the rewrite.
;; test.add(%a, %b, %ignored) → test.fused(%a, %b)
;; The third operand is skipped with _.
(library (passes wildcard-operand)
  (export run-pass)
  (import (except (rnrs) =)
          (only (mlir IR Value) mlir::Value::getType)
          (passes wildcard-common)
          (crest))

  (define-rewrite-pattern (%%wildcard-operand op rewriter)
    :if-match
      %out = test.add (%a %b _)
    :rewrite %out :with
      (%result = test.fused (%a %b) -> (mlir::Value::getType %out)))

  (define run-pass (make-run-pass "test.add" %%wildcard-operand))

  ) ;; end library
