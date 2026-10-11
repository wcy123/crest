#!r6rs
;; Test pass: successful rewrite — test.add → test.add (identity).
;; Used to verify emitted ops carry loc(...) from the pattern source file.
(library (passes debug-match-rewrite)
  (export run-pass)
  (import (except (rnrs) =)
          (only (mlir IR Value) mlir::Value::getType)
          (passes debug-match-common)
          (crest))

  (define-rewrite-pattern (%%rewrite op rewriter)
    :if-match
      %out = test.add (%a %b)
    :rewrite %out :with
      (%result = test.sub (%a %b) -> (mlir::Value::getType %out)))

  (define run-pass (make-run-pass "test.add" %%rewrite))

  ) ;; end library
