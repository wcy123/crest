#!r6rs
(library (passes function-without-callable)
  (export nocallable)
  (import (chezscheme)
          (crest dialect)
          (only (mlir Interfaces FunctionInterfaces) mlir::FunctionOpInterface))

  (define-dialect nocallable
    (define-op func
      :interfaces ((mlir::FunctionOpInterface)))))
