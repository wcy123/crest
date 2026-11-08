#!r6rs
;; Dialect definition isolated so define-dialect :interfaces compilation
;; does not interact with MLIR interface method imports.
(library (passes ifacetest)
  (export %%ifacetest.func:mlir::FunctionOpInterface
          ifacetest)
  (import (chezscheme)
          (crest dialect)
          (only (mlir Interfaces FunctionInterfaces) mlir::FunctionOpInterface))

  (define-dialect ifacetest
    (define-op func
      :interfaces ((mlir::FunctionOpInterface)))))
