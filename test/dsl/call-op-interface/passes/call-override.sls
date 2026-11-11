#!r6rs
(library (passes call-override)
  (export badcall)
  (import (chezscheme)
          (crest dialect)
          (only (mlir Interfaces CallInterfaces) mlir::CallOpInterface mlir::ArgAndResultAttrsOpInterface mlir::CallInterfaceCallable::get<SymbolRefAttr> mlir::CallInterfaceCallable::dyn_cast<SymbolRefAttr> crest::OperandRange::get))

  (define-dialect badcall
    (define-op call
      :interfaces ((mlir::ArgAndResultAttrsOpInterface :standard)
                   (mlir::CallOpInterface
                    (getArgOperands (self) 0))))))
