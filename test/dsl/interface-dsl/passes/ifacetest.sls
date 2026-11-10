#!r6rs
;; Dialect definition isolated so define-dialect :interface2 compilation
;; does not interact with MLIR interface method imports.
(library (passes ifacetest)
  (export ifacetest)
  (import (chezscheme)
          (crest dialect)
          (only (mlir Interfaces FunctionInterfaces) mlir::FunctionOpInterface))

  (define-dialect ifacetest
    (define-op func
      :interface2 ((mlir::FunctionOpInterface)))))
