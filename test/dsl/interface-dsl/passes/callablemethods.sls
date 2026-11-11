#!r6rs
;; Ops whose CallableOpInterface clauses answer all three methods. The ops have no function_type
;; attribute: nothing in CREST decides where a dialect keeps its signature.
(library (passes callablemethods)
  (export callablemethods)
  (import (chezscheme)
          (crest dialect)
          (mlir IR Operation)
          (only (mlir IR BuiltinTypes) mlir::IntegerType::get<i32> mlir::IntegerType::get<i64>
                mlir::Float32Type::get)
          (only (mlir Interfaces CallInterfaces) mlir::CallableOpInterface))

  (define-dialect callablemethods
    (define-op one
      :interfaces ((mlir::CallableOpInterface
                    (getCallableRegion (self) (mlir::Operation::getRegion self 1))
                    (getArgumentTypes (self)
                                      (list (mlir::IntegerType::get<i32>) (mlir::Float32Type::get)))
                    (getResultTypes (self) (list (mlir::IntegerType::get<i64>))))))
    (define-op two
      :interfaces ((mlir::CallableOpInterface
                    (getCallableRegion (self) (mlir::Operation::getRegion self 0))
                    (getArgumentTypes (self) '())
                    (getResultTypes (self)
                                    (list (mlir::Float32Type::get) (mlir::Float32Type::get))))))))
