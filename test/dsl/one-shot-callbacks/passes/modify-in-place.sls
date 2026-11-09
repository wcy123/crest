#!r6rs
;; modifyOpInPlace: a rewrite pattern changes the op it matched through the rewriter, which tells
;; the pattern driver, instead of rewriting it.
(library (passes modify-in-place)
  (export run-pass)
  (import (except (rnrs) =)
          (only (mlir IR Operation)
                mlir::Operation::getContext
                mlir::Operation::getAttr
                mlir::Operation::setAttr!)
          (only (mlir IR MLIRContext) with-current-MLIRContext)
          (only (mlir IR BuiltinAttributes) mlir::UnitAttr::get)
          (only (mlir Transforms DialectConversion) mlir::RewriterBase::modifyOpInPlace)
          (crest))

  (define (%%mark op rewriter)
    (let ([marked (mlir::Operation::getAttr op "marked")])
      (and (or (not marked) (eqv? marked 0))
           (begin
             (mlir::RewriterBase::modifyOpInPlace
              rewriter op
              (lambda () (mlir::Operation::setAttr! op "marked" (mlir::UnitAttr::get))))
             #t))))

  (define (run-pass module-op)
    (let ([ctx (mlir::Operation::getContext module-op)])
      (with-current-MLIRContext ctx
        (apply-patterns module-op ctx :patterns (("test.mark" %%mark 1))))))

  ) ;; end library
