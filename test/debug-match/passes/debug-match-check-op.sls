#!r6rs
;; Test pass: exercises CREST_DEBUG_MATCH=1 for a non-root op mismatch.
;; Root op is test.sub (correctly registered). The pattern also expects
;; its input to be produced by test.add — but the IR has test.mul instead.
;; The framework dispatches on test.sub; the intermediate :check-op fails.
(library (passes debug-match-check-op)
  (export run-pass)
  (import (except (rnrs) =)
          (only (mlir IR Value) mlir::Value::getType)
          (passes debug-match-common)
          (crest))

  (define-rewrite-pattern (%%expect-test.add-then-sub op rewriter)
    :if-match
      %mid = test.add (%a %b)
      %out = test.sub (%mid %c)
    :then-let
      ([!out-type (mlir::Value::getType %out)])
    :rewrite %out :with
      result = test.sub (%mid %c) -> !out-type) ;

  (define run-pass (make-run-pass "test.sub" %%expect-test.add-then-sub))

  ) ;; end library
