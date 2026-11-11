#!r6rs
;; Ops whose :interfaces entries supply method clauses. The clauses announce themselves, so the
;; test can tell that MLIR's call through the Concept reached them.
(library (passes ifaceclauses)
  (export ifaceclauses)
  (import (chezscheme)
          (crest dialect)
          (mlir IR Operation)
          (mlir IR BuiltinAttributes)
          (only (mlir IR BuiltinTypes) mlir::FunctionType::get)
          (only (mlir Interfaces FunctionInterfaces) mlir::FunctionOpInterface)
          (only (mlir Interfaces CallInterfaces) mlir::CallableOpInterface mlir::ArgAndResultAttrsOpInterface))

  (define-dialect ifaceclauses
    (define-op good
      :interfaces ((mlir::ArgAndResultAttrsOpInterface :standard)
                   (mlir::CallableOpInterface
                    (getCallableRegion (self)
                                       (display "clause getCallableRegion\n")
                                       (mlir::Operation::getRegion self 0))
                    (getArgumentTypes (self) '())
                    (getResultTypes (self) '()))
                   (mlir::FunctionOpInterface
                    (getFunctionType (self)
                                     (display "clause getFunctionType\n")
                                     (mlir::TypeAttr::getValue
                                      (mlir::Operation::getAttr self "function_type")))
                    (setFunctionTypeAttr (self attr)
                                         (mlir::Operation::setAttr! self "function_type" attr))
                    (verifyBody (self) (display "clause verifyBody\n") #t)
                    (verifyType (self) (display "clause verifyType\n") #t)
                    ;; Not the default: the inputs come back in the other order.
                    (cloneTypeWith (self inputs results)
                                   (display "clause cloneTypeWith\n")
                                   (mlir::FunctionType::get (mlir::Operation::getContext self) (reverse inputs) results)))))
    (define-op settable
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
                                         (display "clause setFunctionTypeAttr\n")
                                         (mlir::Operation::setAttr! self "function_type" attr)))))
    (define-op bad
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
                                         (mlir::Operation::setAttr! self "function_type" attr))
                    (verifyBody (self) #f)
                    (verifyType (self) #f))))
    (define-op raises
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
                                         (mlir::Operation::setAttr! self "function_type" attr))
                    (verifyBody (self) (error 'verifyBody "the body is broken"))
                    (verifyType (self) (error 'verifyType "the type is broken")))))))
