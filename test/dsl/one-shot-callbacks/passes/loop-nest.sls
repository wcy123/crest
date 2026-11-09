#!r6rs
;; buildAffineLoopNest: the callback of the C++ function builds the body of the nest. It says how many
;; induction variables it got, and the loops are in the module.
(library (passes loop-nest)
  (export run-pass)
  (import (rnrs)
          (only (mlir IR Operation)
                mlir::Operation::getContext
                mlir::Operation::getLoc
                mlir::Operation::getRegion)
          (only (mlir IR Region) mlir::Region::front)
          (only (mlir IR MLIRContext) with-current-MLIRContext mlir::MLIRContext::getOrLoadDialect)
          (only (mlir IR Builders) with-OpBuilder mlir::OpBuilder::atBlockEnd)
          (only (mlir Dialect Affine IR AffineOps) mlir::affine::buildAffineLoopNest))

  (define (run-pass module-op)
    (let ([ctx (mlir::Operation::getContext module-op)])
      (with-current-MLIRContext ctx
        (mlir::MLIRContext::getOrLoadDialect ctx "affine")
        (let ([block (mlir::Region::front (mlir::Operation::getRegion module-op 0))])
          (with-OpBuilder builder (mlir::OpBuilder::atBlockEnd block)
            (mlir::affine::buildAffineLoopNest
             builder (mlir::Operation::getLoc module-op) '(0 0) '(4 8) '(1 2)
             (lambda (nested-builder loc ivs)
               (let ([port (current-output-port)])
                 (display (string-append "induction variables: " (number->string (length ivs)) "\n")
                          port)
                 (flush-output-port port)))))))))

  ) ;; end library
