;; scheme-mlir driver: makes a per-run callback (a walk), so that the prototype of the walk owns a
;; maker, then ends the process. The maker is unlocked when the process ends: that must not crash,
;; whether the program ends normally or through (exit n). Argument 2 is "end" or "exit".
(import (rnrs)
        (only (chezscheme) command-line-arguments)
        (mlir IR DialectRegistry) (mlir IR MLIRContext) (mlir IR Operation) (mlir IR OwningOpRef))

(define args (command-line-arguments))

(with-DialectRegistry reg ()
  (with-MLIRContext ctx (reg)
    (with-mlir::OwningOpRef module (mlir::parseSourceFile ctx (car args))
      (mlir::Operation::walk module (lambda (op) #t)))))
(display "walked\n")
(when (string=? (cadr args) "exit")
  (exit 3))
