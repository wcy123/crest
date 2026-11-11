#!r6rs
;; An op that declares CallableOpInterface but not ArgAndResultAttrsOpInterface, which it extends.
(library (passes callable-without-attrs)
  (export noattrs)
  (import (chezscheme)
          (crest dialect)
          (mlir IR Operation)
          (only (mlir Interfaces CallInterfaces) mlir::CallableOpInterface))

  (define-dialect noattrs
    (define-op callee
      :interfaces ((mlir::CallableOpInterface
                    (getCallableRegion (self) (mlir::Operation::getRegion self 0))
                    (getArgumentTypes (self) '())
                    (getResultTypes (self) '()))))))
