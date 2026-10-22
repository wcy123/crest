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
    :then-let
      ([!out-type (mlir::Value::getType %d)])
    :rewrite %d :with
      result = test.fused (%a %x %y) -> !out-type)

  (define run-pass (make-run-pass "test.sub" %%chain))

  ) ;; end library
