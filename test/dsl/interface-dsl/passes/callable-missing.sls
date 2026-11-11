#!r6rs
(library (passes callable-missing)
  (export missingclauses)
  (import (chezscheme)
          (crest dialect)
          (mlir IR Operation)
          (only (mlir Interfaces CallInterfaces) mlir::CallableOpInterface mlir::ArgAndResultAttrsOpInterface))

  (define-dialect missingclauses
    (define-op callee
      :interfaces ((mlir::ArgAndResultAttrsOpInterface :standard)
                   (mlir::CallableOpInterface
                    (getCallableRegion (self) (mlir::Operation::getRegion self 0)))))))
