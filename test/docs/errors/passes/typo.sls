#!r6rs
(library (passes typo)
  (export pass-entry-point)
  (import (except (rnrs) =)
          (only (mlir IR Value) mlir::Value::getType)
          (only (mlir IR Operation) mlir::Operation::getContext)
          (only (mlir IR MLIRContext) with-current-MLIRContext)
          (crest))

  (define-rewrite-pattern (typo op rewriter)
    :if-mach
      %out = source.add (%x %y)
    :then-let
      ([!result-type (mlir::Value::getType %out)])
    :rewrite %out :with
      result = target.fused (%x %y) -> !result-type)

  (define-pass-entry-point (module-op)
    (let ([ctx (mlir::Operation::getContext module-op)])
      (with-current-MLIRContext ctx
        (apply-patterns module-op ctx :patterns (("source.add" typo))))))
  ) ;; end library
