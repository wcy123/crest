#!r6rs
(library (passes call-override)
  (export badcall)
  (import (chezscheme)
          (crest dialect)
          (only (mlir Interfaces CallInterfaces) mlir::CallOpInterface))

  (define-dialect badcall
    (define-op call
      :interfaces ((mlir::CallOpInterface
                    (getArgOperands (self) 0))))))
