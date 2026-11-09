#!r6rs
;; A walk inside the callback of a walk: the callback of the outer walk runs again, from inside
;; C++, while the inner one runs.
(library (passes walk-nested)
  (export run-pass)
  (import (rnrs)
          (only (mlir IR Operation)
                mlir::Operation::walk
                mlir::Operation::setAttr!
                mlir::Operation::getContext)
          (only (mlir IR MLIRContext) with-current-MLIRContext)
          (only (mlir IR BuiltinAttributes) mlir::IntegerAttr::get<i64>))

  (define (run-pass module-op)
    (with-current-MLIRContext (mlir::Operation::getContext module-op)
      (let ([outer 0] [inner 0])
        (mlir::Operation::walk
         module-op
         (lambda (op)
           (set! outer (+ outer 1))
           (mlir::Operation::walk op (lambda (nested) (set! inner (+ inner 1))))))
        (mlir::Operation::setAttr! module-op "test.outer" (mlir::IntegerAttr::get<i64> outer))
        (mlir::Operation::setAttr! module-op "test.inner" (mlir::IntegerAttr::get<i64> inner)))))

  ) ;; end library
