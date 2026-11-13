#!r6rs
;; Diamond pattern with optional operands.
;; Both test.add and test.sub must share the SAME %shared operand.
(library (passes flex-diamond)
  (export pass-entry-point)
  (import (except (rnrs) =)
          (only (mlir IR Value) mlir::Value::getType)
          (passes operands-common)
          (crest))

  (define-rewrite-pattern (%%match op rewriter)
    :if-match
      %left  = test.add     (%shared (:optional %x))
      %right = test.sub     (%shared (:optional %y))
      %out   = test.combine (%left %right)
    :then-let
      ([!out-type (mlir::Value::getType %out)])
    :rewrite %out :with
      result = test.fused (%shared) -> !out-type) ;

  (define-pass-entry-point (module-op) ((make-pass-body "test.combine" %%match) module-op))

  ) ;; end library
