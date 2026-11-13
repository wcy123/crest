#!r6rs
;; Test pass: successful rewrite — test.add → test.add (identity).
;; Used to verify emitted ops carry loc(...) from the pattern source file.
(library (passes debug-match-rewrite)
  (export pass-entry-point)
  (import (except (rnrs) =)
          (only (mlir IR Value) mlir::Value::getType)
          (passes debug-match-common)
          (crest))

  (define-rewrite-pattern (%%rewrite op rewriter)
    :if-match
      %out = test.add (%a %b)
    :then-let
      ([!out-type (mlir::Value::getType %out)])
    :rewrite %out :with
      result = test.sub (%a %b) -> !out-type) ;

  (define-pass-entry-point (module-op) ((make-pass-body "test.add" %%rewrite) module-op))

  ) ;; end library
