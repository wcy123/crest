#!r6rs
;; A function op that gives only the two methods that MLIR has no default for: the rest is what MLIR
;; does for an op that does not override them.
(library (passes fdefaults)
  (export fdefaults)
  (import (chezscheme)
          (crest dialect)
          (mlir IR Operation)
          (mlir IR BuiltinAttributes)
          (only (mlir IR BuiltinTypes) mlir::FunctionType::getInputs mlir::FunctionType::getResults)
          (only (mlir Interfaces FunctionInterfaces) mlir::FunctionOpInterface)
          (only (mlir Interfaces CallInterfaces) mlir::CallableOpInterface mlir::ArgAndResultAttrsOpInterface))

  (define-dialect fdefaults
    (define-op fn
      :interfaces ((mlir::ArgAndResultAttrsOpInterface :standard)
                   (mlir::CallableOpInterface
                    (getCallableRegion (self) (mlir::Operation::getRegion self 0))
                    (getArgumentTypes (self)
                                      (mlir::FunctionType::getInputs
                                       (mlir::TypeAttr::getValue (mlir::Operation::getAttr self "function_type"))))
                    (getResultTypes (self)
                                    (mlir::FunctionType::getResults
                                     (mlir::TypeAttr::getValue (mlir::Operation::getAttr self "function_type")))))
                   (mlir::FunctionOpInterface
                    (getFunctionType (self)
                                     (mlir::TypeAttr::getValue (mlir::Operation::getAttr self "function_type")))
                    (setFunctionTypeAttr (self attr)
                                         (mlir::Operation::setAttr! self "function_type" attr)))))))
