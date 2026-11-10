#!r6rs
;; A dialect with one op per interface of the :interface2 clause, and one with none: the ops of
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
    (define-op func   :interface2 ((mlir::FunctionOpInterface)))
    (define-op callee :interface2 ((mlir::CallableOpInterface)))
    (define-op call   :interface2 ((mlir::CallOpInterface)))
    (define-op attrs  :interface2 ((mlir::ArgAndResultAttrsOpInterface)))
    (define-op symbol :interface2 ((mlir::SymbolOpInterface)))
    (define-op effect :interface2 ((mlir::MemoryEffectOpInterface) (mlir::ConditionallySpeculatable)))
    (define-op bare)))
