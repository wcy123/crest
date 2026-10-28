#!r6rs
;; Test: :loc expr overrides the auto-derived Scheme source location on emitted ops.
;;
;; Rewrites test.add(%a, %b) → test.sub(%a, %b) with a runtime-constructed
;; FileLineColLoc("fake-source.toy", 42, 1).  The MLIR output must carry that
;; synthetic location, NOT the location of this .sls file.
(library (passes loc-override)
  (export run-pass)
  (import (except (rnrs) =)
          (only (mlir IR Value) mlir::Value::getType)
          (only (mlir IR Location) mlir::FileLineColLoc::get)
          (passes loc-override-common)
          (crest))

  (define-rewrite-pattern (%%rewrite op rewriter)
    :if-match
      %out = test.add (%a %b)
    :then-let
      ([!out-type (mlir::Value::getType %out)]
       [my-loc    (mlir::FileLineColLoc::get "fake-source.toy" 42 1)])
    :rewrite %out :with
      result = test.sub (%a %b) -> !out-type
    :loc my-loc)

  (define run-pass (make-run-pass "test.add" %%rewrite))

  ) ;; end library
