;; Test driver for scheme-mlir: makes an f64 attribute in a context that Scheme owns (with-MLIRContext),
;; once with the current context and once with the context given. The binding used to cast the handle
;; straight to MLIRContext* and crashed, as it is a box and not the raw pointer MLIR passes to passes.
(import (chezscheme)
        (mlir IR DialectRegistry) (mlir IR MLIRContext) (mlir IR BuiltinAttributes))

(with-DialectRegistry reg ()
  (with-MLIRContext ctx (reg)
    (with-current-MLIRContext ctx
      (display (mlir::FloatAttr::getValueAsDouble (mlir::FloatAttr::get<f64> 1.5)))
      (newline)
      (display (mlir::FloatAttr::getValueAsDouble (mlir::FloatAttr::get<f64> ctx 2.25)))
      (newline))))
