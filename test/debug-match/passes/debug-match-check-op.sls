#!r6rs
;; Test pass: exercises :check-op debug output.
;; Pattern expects "test.add"; test MLIR has "test.sub" — op name mismatch.
(library (passes debug-match-check-op)
  (export run-pass)
  (import (except (rnrs) =)
          (only (mlir IR Value) mlir::Value::getType)
          (passes debug-match-common)
          (crest))

  (define-rewrite-pattern (%%pattern op rewriter)
    :if-match
      %out = test.add (%a %b)
    :rewrite %out :with
      (%result = test.add (%a %b) -> (mlir::Value::getType %out)))

  (define run-pass (make-run-pass "test.sub" %%pattern))

  ) ;; end library
