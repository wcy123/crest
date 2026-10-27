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
          (mlir IR BuiltinTypes)
          (mlir IR BuiltinAttributes)
          (only (mlir Interfaces FunctionInterfaces)
                mlir::FunctionOpInterface
                mlir::FunctionOpInterface::getFunctionType
                mlir::FunctionOpInterface::verifyBody
                mlir::FunctionOpInterface::verifyType))

  (define-dialect ifacetest
    (define-op func
      :interfaces
      ((mlir::FunctionOpInterface))))

  (define (run-pass module)
    (let ([ctx (mlir::Operation::getContext module)])
      (with-current-MLIRContext ctx
        (ifacetest:register! ctx)))
    module)

  ) ;; end library (passes interface-dsl)
