#!r6rs
;; Test pass: exercises :check-where FAILED: debug output with file:line:col.
;; The :where guard (eqv? 1 2) always returns #f cleanly — no exception —
;; so CREST_DEBUG_MATCH prints FAILED: with the source location.
(library (passes debug-match-check-where)
  (export run-pass)
  (import (except (rnrs) =)
          (only (mlir IR Value) mlir::Value::getType)
          (passes debug-match-common)
          (crest))

  (define-rewrite-pattern (%%where-always-false op rewriter)
    :if-match
      %out = test.add (%a %b)
        :where (eqv? 1 2)
    :then-let
      ([!out-type (mlir::Value::getType %out)])
    :rewrite %out :with
      result = test.add (%a %b) -> !out-type)

  (define run-pass (make-run-pass "test.add" %%where-always-false))

  ) ;; end library
