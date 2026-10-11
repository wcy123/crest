#!r6rs
;; Test pass: exercises always-on exception logging.
;; (:attr "missing") on test.add — attribute never exists → unexpected error
;; always logged via crest::logging::warning regardless of CREST_DEBUG_MATCH.
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
    :rewrite %out :with
      (%result = test.add (%a %b) -> (mlir::Value::getType %out)))

  (define run-pass (make-run-pass "test.add" %%require-missing-attr))

  ) ;; end library
