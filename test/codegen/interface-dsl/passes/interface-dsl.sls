#!r6rs
;; Unit test for the :interfaces DSL.
;; Registers a dialect with mlir::FunctionOpInterface and verifies that the
;; interface methods dispatch correctly via the C++ concept registry.
(library (passes interface-dsl)
  (export run-pass)
  (import (chezscheme)
          (crest dialect)
          (mlir IR Operation)
          (mlir IR MLIRContext)
          (mlir Interfaces FunctionInterfaces))

  (define-dialect ifacetest
    (define-op func
      :interfaces
      ((mlir::FunctionOpInterface))))

  (define (run-pass module)
    (let ([ctx (mlir::Operation::getContext module)])
      (with-current-MLIRContext ctx
        (ifacetest:register! ctx)))
    module)
  )
