#!r6rs
(library (passes falsy)
  (export pass-entry-point)
  (import (except (rnrs) =)
          (only (mlir IR Value) mlir::Value::getType)
          (only (mlir IR Operation) mlir::Operation::getContext)
          (only (mlir IR MLIRContext) with-current-MLIRContext)
          (crest))

  (define-rewrite-pattern (falsy op rewriter)
    :if-match
      %out = source.add (%x %y)
        :where #f
    :then-let
      ([!result-type (mlir::Value::getType %out)])
    :rewrite %out :with
      result = target.fused (%x %y) -> !result-type)

  (define-pass-entry-point (module-op)
    (let ([ctx (mlir::Operation::getContext module-op)])
      (with-current-MLIRContext ctx
        (apply-patterns module-op ctx :patterns (("source.add" falsy))))))
  ) ;; end library
