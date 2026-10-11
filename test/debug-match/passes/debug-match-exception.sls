#!r6rs
;; Test pass: exercises always-on exception logging (production, no CREST_DEBUG_MATCH).
;; A :where clause that throws (division by zero) triggers the per-check guard,
;; which logs the exception regardless of CREST_DEBUG_MATCH.
(library (passes debug-match-exception)
  (export run-pass)
  (import (except (rnrs) =)
          (only (mlir IR Value) mlir::Value::getType)
          (passes debug-match-common)
          (crest))

  (define-rewrite-pattern (%%always-throws op rewriter)
    :if-match
      %out = test.add (%a %b)
        :where (eqv? (/ 1 0) 0)
    :rewrite %out :with
      (%result = test.add (%a %b) -> (mlir::Value::getType %out)))

  (define run-pass (make-run-pass "test.add" %%always-throws))

  ) ;; end library
