#!r6rs
;; Test pass: exercises always-on exception logging (production, no CREST_DEBUG_MATCH).
;; A :where clause that throws (division by zero) triggers the per-check guard,
;; which logs the exception regardless of CREST_DEBUG_MATCH.
(library (passes debug-match-exception)
  (export pass-entry-point)
  (import (except (rnrs) =)
          (only (mlir IR Value) mlir::Value::getType)
          (passes debug-match-common)
          (crest))

  (define-rewrite-pattern (%%always-throws op rewriter)
    :if-match
      %out = test.add (%a %b)
        :where (eqv? (/ 1 0) 0)
    :then-let
      ([!out-type (mlir::Value::getType %out)])
    :rewrite %out :with
      result = test.add (%a %b) -> !out-type) ;

  (define-pass-entry-point (module-op) ((make-pass-body "test.add" %%always-throws) module-op))

  ) ;; end library
