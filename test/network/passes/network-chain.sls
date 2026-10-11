#!r6rs
;; Linear chain topology: A → B → C → D
;;
;;   %a ──► test.mul ──► %b ──► test.add ──► %c ──► test.sub ──► %d
;;
;; Each :set-current-op walks one step up the def-use chain.
(library (passes network-chain)
  (export run-pass)
  (import (except (rnrs) =)
          (only (mlir IR Value) mlir::Value::getType)
          (passes network-common)
          (crest))

  (define-rewrite-pattern (%%chain op rewriter)
    :if-match
      %b = test.mul (%a)
      %c = test.add (%b %x)
      %d = test.sub (%c %y)
    :rewrite %d :with
      (%result = test.fused (%a %x %y) -> (mlir::Value::getType %d)))

  (define run-pass (make-run-pass "test.sub" %%chain))

  ) ;; end library
