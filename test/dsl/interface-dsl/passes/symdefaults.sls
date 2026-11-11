#!r6rs
;; Ops with the SymbolOpInterface of MLIR: no clause, so every method is what MLIR does by default
;; (the name is "sym_name", the visibility "sym_visibility"); one op overrides two methods.
(library (passes symdefaults)
  (export symdefaults)
  (import (chezscheme)
          (crest dialect)
          (mlir IR Operation)
          (only (mlir IR SymbolInterfaces) mlir::SymbolOpInterface))

  (define-dialect symdefaults
    (define-op sym
      :interfaces ((mlir::SymbolOpInterface)))
    (define-op overriding
      :interfaces ((mlir::SymbolOpInterface
                    (isDeclaration (self) #t)
                    (isOptionalSymbol (self) #t))))))
