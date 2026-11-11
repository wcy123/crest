;; scheme-mlir driver: with-mlir::OwningOpRef parses a file and erases the module at the end of its
;; body. A file that does not exist gives 0 and nothing is erased. The module is also erased when the
;; body raises an error or escapes.
(import (rnrs)
        (only (chezscheme) command-line-arguments)
        (mlir IR DialectRegistry) (mlir IR MLIRContext) (mlir IR Operation) (mlir IR OwningOpRef))

(define good (car (command-line-arguments)))

(with-DialectRegistry reg ()
  (with-MLIRContext ctx (reg)
    ;; a file that parses: the module is a real operation
    (with-mlir::OwningOpRef module (mlir::parseSourceFile ctx good)
      (display (mlir::Operation::getName module))
      (newline))
    ;; a file that does not exist: the module is 0
    (with-mlir::OwningOpRef module (mlir::parseSourceFile ctx "/does/not/exist.mlir")
      (display (if (eqv? module 0) "no module" "module"))
      (newline))
    ;; the body raises an error
    (guard (c [#t (display "caught\n")])
      (with-mlir::OwningOpRef module (mlir::parseSourceFile ctx good)
        (error 'owning-op-ref "boom")))
    ;; the body escapes
    (call/cc (lambda (k)
               (with-mlir::OwningOpRef module (mlir::parseSourceFile ctx good)
                 (k 'out))))
    (display "end\n")))
