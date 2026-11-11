#!r6rs
;; A function op that declares everything it extends except SymbolOpInterface.
(library (passes function-without-symbol)
  (export nosymbol)
  (import (chezscheme)
          (crest dialect)
          (mlir IR Operation)
          (mlir IR BuiltinAttributes)
          (only (mlir Interfaces FunctionInterfaces) mlir::FunctionOpInterface)
          (only (mlir Interfaces CallInterfaces)
                mlir::CallableOpInterface mlir::ArgAndResultAttrsOpInterface))

  (define-dialect nosymbol
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
