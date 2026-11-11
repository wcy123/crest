#!r6rs
;; A dialect with one op per interface of the :interfaces clause, and one with none: the ops of
;; unittests/Crest/InterfaceTest.cpp, which asks the interface map of each what it has. The dialect
;; has an inliner interface of its own (the :interfaces clause of the dialect).
(library (passes ifacemap)
  (export ifacemap)
  (import (chezscheme)
          (crest dialect)
          (mlir IR Operation)
          (only (mlir Interfaces FunctionInterfaces) mlir::FunctionOpInterface)
          (only (mlir Interfaces CallInterfaces)
                mlir::CallableOpInterface mlir::CallOpInterface mlir::ArgAndResultAttrsOpInterface)
          (only (mlir IR SymbolInterfaces) mlir::SymbolOpInterface)
          (only (mlir Transforms InliningUtils) mlir::DialectInlinerInterface)
          (only (mlir Interfaces SideEffectInterfaces)
                mlir::MemoryEffectOpInterface mlir::ConditionallySpeculatable))

  (define-dialect ifacemap
    (:interfaces ((mlir::DialectInlinerInterface
                   (isLegalToInline/call   (call callable would-be-cloned) #t)
                   (isLegalToInline/region (dest src would-be-cloned) #t)
                   (isLegalToInline/op     (op dest would-be-cloned) #t))))
    (define-op func
      :interfaces ((mlir::CallableOpInterface
                    (getCallableRegion (self) (mlir::Operation::getRegion self 0))
                    (getArgumentTypes (self) '())
                    (getResultTypes (self) '()))
                   (mlir::FunctionOpInterface)))
    (define-op callee
      :interfaces ((mlir::CallableOpInterface
                    (getCallableRegion (self) (mlir::Operation::getRegion self 0))
                    (getArgumentTypes (self) '())
                    (getResultTypes (self) '()))))
    (define-op call   :interfaces ((mlir::CallOpInterface)))
    (define-op attrs  :interfaces ((mlir::ArgAndResultAttrsOpInterface)))
    (define-op symbol :interfaces ((mlir::SymbolOpInterface)))
    (define-op effect :interfaces ((mlir::MemoryEffectOpInterface) (mlir::ConditionallySpeculatable)))
    (define-op bare)))
