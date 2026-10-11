#!r6rs
;; Shared infrastructure for operand binding tests.
(library (passes operands-common)
  (export make-run-pass)
  (import (except (rnrs) =)
          (only (mlir IR Operation) mlir::Operation::getContext)
          (only (mlir IR MLIRContext) with-current-MLIRContext)
          (only (mlir IR PatternMatch) with-RewritePatternSet)
          (only (mlir Transforms GreedyPatternRewriteDriver) mlir::applyPatternsGreedily)
          (only (mlir Transforms DialectConversion) add-rewrite-pattern))

  (define (make-run-pass root-op-name pattern)
    (lambda (module-op)
      (let ([ctx (mlir::Operation::getContext module-op)])
        (with-current-MLIRContext ctx
                                  (with-RewritePatternSet (patterns ctx)
                                                          (add-rewrite-pattern patterns root-op-name pattern 1)
                                                          (mlir::applyPatternsGreedily module-op patterns))))))

  ) ;; end library
