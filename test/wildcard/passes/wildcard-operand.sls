#!r6rs
;; _ in operand position: skip operands we don't need in the rewrite.
;; test.add(%a, %b, %ignored) → test.fused(%a, %b)
;; The third operand is skipped with _.
(library (passes wildcard-operand)
  (export pass-entry-point)
  (import (except (rnrs) =)
          (only (mlir IR Value) mlir::Value::getType)
          (passes wildcard-common)
          (crest))

  (define-rewrite-pattern (%%wildcard-operand op rewriter)
    :if-match
      %out = test.add (%a %b _)
    :then-let
      ([!out-type (mlir::Value::getType %out)])
    :rewrite %out :with
      result = test.fused (%a %b) -> !out-type) ;

  (define-pass-entry-point (module-op) ((make-pass-body "test.add" %%wildcard-operand) module-op))

  ) ;; end library
