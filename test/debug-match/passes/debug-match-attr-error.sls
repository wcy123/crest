#!r6rs
;; Test pass: exercises :check-where FAILED: debug output.
;; (:attr "missing") on test.add — attribute absent → #f (clean match failure).
;; With CREST_DEBUG_MATCH=1, prints FAILED: with file:line:col and actual: op.
(library (passes debug-match-attr-error)
  (export run-pass)
  (import (except (rnrs) =)
          (only (mlir IR Value) mlir::Value::getType)
          (passes debug-match-common)
          (crest))

  (define-rewrite-pattern (%%require-missing-attr op rewriter)
    :if-match
      %out = test.add (%a %b)
        :where (:attr "missing")
    :then-let
      ([!out-type (mlir::Value::getType %out)])
    :rewrite %out :with
      result = test.add (%a %b) -> !out-type) ;

  (define run-pass (make-run-pass "test.add" %%require-missing-attr))

  ) ;; end library
