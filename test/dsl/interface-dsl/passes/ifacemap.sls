#!r6rs
;; A dialect with one op per interface of the :interfaces clause, and one with none: the ops of
;; unittests/Crest/InterfaceTest.cpp, which asks the interface map of each what it has.
(library (passes ifacemap)
  (export ifacemap)
  (import (chezscheme)
          (crest dialect)
          (only (mlir Interfaces FunctionInterfaces) mlir::FunctionOpInterface)
          (only (mlir Interfaces CallInterfaces)
                mlir::CallableOpInterface mlir::CallOpInterface mlir::ArgAndResultAttrsOpInterface)
          (only (mlir IR SymbolInterfaces) mlir::SymbolOpInterface)
          (only (mlir Interfaces SideEffectInterfaces)
                mlir::MemoryEffectOpInterface mlir::ConditionallySpeculatable))

  (define-dialect ifacemap
    (define-op func   :interfaces ((mlir::FunctionOpInterface)))
    (define-op callee :interfaces ((mlir::CallableOpInterface)))
    (define-op call   :interfaces ((mlir::CallOpInterface)))
    (define-op attrs  :interfaces ((mlir::ArgAndResultAttrsOpInterface)))
    (define-op symbol :interfaces ((mlir::SymbolOpInterface)))
    (define-op effect :interfaces ((mlir::MemoryEffectOpInterface) (mlir::ConditionallySpeculatable)))
    (define-op bare)))
