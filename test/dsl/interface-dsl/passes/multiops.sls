#!r6rs
;; Several ops of one dialect with different clauses for the same methods, and ops without a clause:
;; each op must get its own.
(library (passes multiops)
  (export multiops)
  (import (chezscheme)
          (crest dialect)
          (mlir IR Operation)
          (mlir IR BuiltinAttributes)
          (only (mlir IR BuiltinTypes) mlir::FunctionType::get mlir::IntegerType::get<i32>
                mlir::IntegerType::get<i64>)
          (only (mlir Interfaces FunctionInterfaces) mlir::FunctionOpInterface)
          (only (mlir Interfaces CallInterfaces) mlir::CallableOpInterface))

  (define (function-type ctx in out)
    (mlir::FunctionType::get ctx (list in) (list out)))

  (define-dialect multiops
    ;; Callable ops: the region that the clause answers is its own.
    (define-op first
      :interfaces ((mlir::CallableOpInterface
                    (getCallableRegion (self) (mlir::Operation::getRegion self 0))
                    (getArgumentTypes (self) '())
                    (getResultTypes (self) '()))))
    (define-op second
      :interfaces ((mlir::CallableOpInterface
                    (getCallableRegion (self) (mlir::Operation::getRegion self 1))
                    (getArgumentTypes (self) '())
                    (getResultTypes (self) '()))))
    (define-op third
      :interfaces ((mlir::CallableOpInterface
                    (getCallableRegion (self) (mlir::Operation::getRegion self 2))
                    (getArgumentTypes (self) '())
                    (getResultTypes (self) '()))))
    (define-op plain
      :interfaces ((mlir::CallableOpInterface
                    (getCallableRegion (self) (mlir::Operation::getRegion self 0))
                    (getArgumentTypes (self) '())
                    (getResultTypes (self) '()))))
    ;; Function ops: each has its own type, verifier and setter.
    (define-op fn-a
      :interfaces ((mlir::CallableOpInterface
                    (getCallableRegion (self) (mlir::Operation::getRegion self 0))
                    (getArgumentTypes (self) '())
                    (getResultTypes (self) '()))
                   (mlir::FunctionOpInterface
                    (getFunctionType (self)
                                     (function-type (mlir::Operation::getContext self)
                                                    (mlir::IntegerType::get<i32>)
                                                    (mlir::IntegerType::get<i32>)))
                    (setFunctionTypeAttr (self attr)
                                         (mlir::Operation::setAttr! self "set_by_a" attr))
                    (verifyBody (self) #t))))
    (define-op fn-b
      :interfaces ((mlir::CallableOpInterface
                    (getCallableRegion (self) (mlir::Operation::getRegion self 0))
                    (getArgumentTypes (self) '())
                    (getResultTypes (self) '()))
                   (mlir::FunctionOpInterface
                    (getFunctionType (self)
                                     (function-type (mlir::Operation::getContext self)
                                                    (mlir::IntegerType::get<i64>)
                                                    (mlir::IntegerType::get<i64>)))
                    (setFunctionTypeAttr (self attr)
                                         (mlir::Operation::setAttr! self "set_by_b" attr))
                    (verifyBody (self) #f))))
    (define-op fn-c
      :interfaces ((mlir::CallableOpInterface
                    (getCallableRegion (self) (mlir::Operation::getRegion self 0))
                    (getArgumentTypes (self) '())
                    (getResultTypes (self) '()))
                   (mlir::FunctionOpInterface
                    (getFunctionType (self)
                                     (mlir::TypeAttr::getValue
                                      (mlir::Operation::getAttr self "function_type")))
                    (setFunctionTypeAttr (self attr)
                                         (mlir::Operation::setAttr! self "function_type" attr)))))))
