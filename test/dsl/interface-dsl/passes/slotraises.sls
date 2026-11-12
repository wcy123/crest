#!r6rs
;; An op whose CallableOpInterface clauses raise an error: the clause of getArgumentTypes (a range), the clause of
;; getCallableRegion (a pointer).
(library (passes slotraises)
  (export slotraises)
  (import (chezscheme)
          (crest dialect)
          (mlir IR Operation)
          (only (mlir Interfaces CallInterfaces) mlir::CallableOpInterface mlir::ArgAndResultAttrsOpInterface))

  (define-dialect slotraises
    (define-op op
      :interfaces ((mlir::ArgAndResultAttrsOpInterface :standard)
                   (mlir::CallableOpInterface
                    (getCallableRegion (self) (error 'getCallableRegion "the region clause is broken"))
                    (getArgumentTypes (self) (error 'getArgumentTypes "the arguments clause is broken"))
                    (getResultTypes (self) '()))))))
