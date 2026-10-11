#!r6rs
;; Test pass: exercises :check-where debug output.
;; Pattern matches test.add but :where guard always fails (0 == 99).
(library (passes debug-match-check-where)
  (export run-pass)
  (import (except (rnrs) =)
          (only (mlir IR Value) mlir::Value::getType)
          (only (mlir IR Operation) mlir::Operation::getNumResults)
          (only (mlir IR Value) mlir::Value::getDefiningOp)
          (passes debug-match-common)
          (crest))

  (define-rewrite-pattern (%%check-where-always-false op rewriter)
    :if-match
      %out = test.add (%a %b)
        :where (eqv? (mlir::Operation::getNumResults
                      (mlir::Value::getDefiningOp %a)) 99)
    :rewrite %out :with
      (%result = test.add (%a %b) -> (mlir::Value::getType %out)))

  (define run-pass (make-run-pass "test.add" %%check-where-always-false))

  ) ;; end library
