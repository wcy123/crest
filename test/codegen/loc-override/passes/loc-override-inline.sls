#!r6rs
;; Test: :loc (filename line column) inline shorthand.
;;
;; Same rewrite as loc-override.sls but uses the inline triple form
;; instead of pre-constructing a FileLineColLoc in :then-let.
(library (passes loc-override-inline)
  (export run-pass)
  (import (except (rnrs) =)
          (only (mlir IR Value) mlir::Value::getType)
          (passes loc-override-common)
          (crest))

  (define-rewrite-pattern (%%rewrite op rewriter)
    :if-match
      %out = test.add (%a %b)
    :then-let
      ([!out-type (mlir::Value::getType %out)])
    :rewrite %out :with
      result = test.sub (%a %b) -> !out-type
    :loc ("inline-source.toy" 7 3))

  (define run-pass (make-run-pass "test.add" %%rewrite))

  ) ;; end library
