;; scheme-mlir driver: the pieces that a callable's guard uses to report an error: a location made from a Scheme source
;; position, a diagnostic at it, and the fatal error of LLVM.
(import (chezscheme)
        (mlir IR DialectRegistry) (mlir IR MLIRContext) (mlir IR Location) (mlir IR Diagnostics)
        (llvm Support ErrorHandling))

(define mode (car (command-line-arguments)))

(with-DialectRegistry reg ()
  (with-MLIRContext ctx (reg)
    (let ([position (mlir::FileLineColLoc::get ctx "scheme-source.sls" 12 5)])
      (cond
       [(string=? mode "locations")
        (mlir::emitError position "reported at a Scheme position")]
       [(string=? mode "fatal")
        (llvm::report_fatal_error "the callback failed")
        (display "not reached\n")]
       [else (error 'driver "unknown mode" mode)]))))
