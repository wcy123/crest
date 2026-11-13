#!r6rs
;; Test pass: exercises FAILED: without actual: (branch 4).
;; Pattern expects test.sub's operand to be produced by test.add.
;; When the operand is a block argument (no defining op), :set-current-op
;; returns #f — FAILED: is logged but no actual: (no op to print).
(library (passes debug-match-no-actual)
  (export pass-entry-point)
  (import (except (rnrs) =)
          (only (mlir IR Value) mlir::Value::getType)
          (passes debug-match-common)
          (crest))

  (define-rewrite-pattern (%%chain-no-actual op rewriter)
    :if-match
      %mid = test.add (%x)
      %out = test.sub (%mid)
    :then-let
      ([!out-type (mlir::Value::getType %out)])
    :rewrite %out :with
      result = test.sub (%mid) -> !out-type) ;

  (define-pass-entry-point (module-op) ((make-pass-body "test.sub" %%chain-no-actual) module-op))

  ) ;; end library
