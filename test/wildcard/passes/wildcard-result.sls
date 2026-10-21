#!r6rs
;; _ in result position: bind only the result we care about.
;; (_ %second) = test.split(%x)  — discard result 0, bind result 1.
;; test.use(%second) → test.fused(%x)
(library (passes wildcard-result)
  (export run-pass)
  (import (except (rnrs) =)
          (only (mlir IR Value) mlir::Value::getType)
          (passes wildcard-common)
          (crest))

  (define-rewrite-pattern (%%wildcard-result op rewriter)
    :if-match
      (_ %second) = test.split (%x)
      %out         = test.use   (%second)
    :rewrite %out :with
      (%result = test.fused (%x) -> (mlir::Value::getType %out)))

  (define run-pass (make-run-pass "test.use" %%wildcard-result))

  ) ;; end library
