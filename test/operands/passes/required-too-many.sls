#!r6rs
;; Negative: pattern expects 2 required operands, op has 3.
;; Documents that the all-required path binds by index — extra operands are
;; silently ignored and the pattern fires on the first 2.
(library (passes required-too-many)
  (export run-pass)
  (import (except (rnrs) =)
          (only (mlir IR Value) mlir::Value::getType)
          (passes operands-common)
          (crest))

  (define-rewrite-pattern (%%match op rewriter)
    :if-match
      %out = test.add (%a %b)
    :then-let
      ([!out-type (mlir::Value::getType %out)])
    :rewrite %out :with
      result = test.fused (%a %b) -> !out-type) ;

  (define run-pass (make-run-pass "test.add" %%match))

  ) ;; end library
