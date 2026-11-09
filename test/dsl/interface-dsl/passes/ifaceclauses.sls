#!r6rs
;; Ops whose :interfaces entries supply method clauses. The clauses announce themselves, so the
;; test can tell that MLIR's call through the Concept reached them.
(library (passes ifaceclauses)
  (export ifaceclauses)
  (import (chezscheme)
          (crest dialect)
          (mlir IR Operation)
          (mlir IR BuiltinAttributes)
          (only (mlir Interfaces FunctionInterfaces) mlir::FunctionOpInterface)
          (only (mlir Interfaces CallInterfaces) mlir::CallableOpInterface))

  (define-dialect ifaceclauses
    (define-op good
      :interfaces ((mlir::CallableOpInterface
                    (getCallableRegion (self)
                                       (display "clause getCallableRegion\n")
                                       (mlir::Operation::getRegion self 0)))
                   (mlir::FunctionOpInterface
                    (getFunctionType (self)
                                     (display "clause getFunctionType\n")
                                     (mlir::TypeAttr::getValue
                                      (mlir::Operation::getAttr self "function_type")))
                    (verifyBody (self) (display "clause verifyBody\n") #t)
                    (verifyType (self) (display "clause verifyType\n") #t))))
    (define-op bad
      :interfaces ((mlir::FunctionOpInterface
                    (verifyBody (self) #f)
                    (verifyType (self) #f))))))
