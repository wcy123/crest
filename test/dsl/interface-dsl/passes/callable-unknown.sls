#!r6rs
(library (passes callable-unknown)
  (export unknownclause)
  (import (chezscheme)
          (crest dialect)
          (mlir IR Operation)
          (only (mlir Interfaces CallInterfaces) mlir::CallableOpInterface))

  (define-dialect unknownclause
    (define-op callee
      :interfaces ((mlir::CallableOpInterface
                    (getCallableRegion (self) (mlir::Operation::getRegion self 0))
                    (getArgumentTypes (self) '())
                    (getResultTypes (self) '())
                    (getCalleeRegion (self) 0))))))
