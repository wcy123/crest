#!r6rs
;; Dialect definition isolated so define-dialect :interfaces compilation
;; does not interact with MLIR interface method imports.
(library (passes ifacetest)
  (export ifacetest)
  (import (chezscheme)
          (crest dialect)
          (only (mlir Interfaces FunctionInterfaces) mlir::FunctionOpInterface)
          (only (mlir Interfaces CallInterfaces) mlir::CallableOpInterface mlir::ArgAndResultAttrsOpInterface)
          (mlir IR Operation)
          (mlir IR BuiltinAttributes))

  (define-dialect ifacetest
    (define-op func
      :interfaces ((mlir::ArgAndResultAttrsOpInterface :standard)
                   (mlir::CallableOpInterface
                    (getCallableRegion (self) (mlir::Operation::getRegion self 0))
                    (getArgumentTypes (self) '())
                    (getResultTypes (self) '()))
                   (mlir::FunctionOpInterface
                    (getFunctionType (self)
                                     (mlir::TypeAttr::getValue
                                      (mlir::Operation::getAttr self "function_type")))
                    (setFunctionTypeAttr (self attr)
                                         (mlir::Operation::setAttr! self "function_type" attr)))))))
