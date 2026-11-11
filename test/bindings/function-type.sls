;; Test driver for scheme-mlir: the input and result types of a FunctionType, as lists.
(import (chezscheme)
        (mlir IR MLIRContext)
        (mlir IR Types)
        (only (mlir IR BuiltinTypes)
              mlir::FunctionType::get
              mlir::FunctionType::getInputs
              mlir::FunctionType::getResults
              mlir::IntegerType::get<i32>
              mlir::IntegerType::get<i64>
              mlir::Float32Type::get))

(let* ([ctx (mlir::MLIRContext::new)]
       [type (mlir::FunctionType::get ctx
                                      (list (mlir::IntegerType::get<i32> ctx) (mlir::Float32Type::get ctx))
                                      (list (mlir::IntegerType::get<i64> ctx)))]
       [empty (mlir::FunctionType::get ctx '() '())])
  (display (list 'inputs (map mlir::Type::print (mlir::FunctionType::getInputs type)))) (newline)
  (display (list 'results (map mlir::Type::print (mlir::FunctionType::getResults type)))) (newline)
  (display (list 'empty (mlir::FunctionType::getInputs empty) (mlir::FunctionType::getResults empty)))
  (newline))
