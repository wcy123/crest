;; Calls the methods of CallableOpInterface on the op of the slotraises dialect, whose clauses raise errors.
;; Each error is a diagnostic at the clause, and the slot answers its zero: no region, no types.
(import (chezscheme)
        (crest dialect)
        (mlir IR Operation)
        (mlir IR MLIRContext)
        (mlir IR OwningOpRef)
        (mlir IR DialectRegistry)
        (only (mlir Support WalkResult) mlir::WalkResult::advance)
        (only (mlir Interfaces CallInterfaces)
              mlir::CallableOpInterface::getCallableRegion
              mlir::CallableOpInterface::getArgumentTypes))

(define (say . parts) (for-each display parts) (newline))

(with-DialectRegistry reg ()
  (with-MLIRContext ctx (reg)
    (mlir::MLIRContext::allowUnregisteredDialects ctx #t)
    (load-scheme-dialect! ctx "slotraises" "passes/slotraises")
    (with-mlir::OwningOpRef module (mlir::parseSourceFile ctx (car (command-line-arguments)))
      (with-current-MLIRContext ctx
        (let ([found #f])
          (mlir::Operation::walk
           module
           (lambda (op)
             (when (equal? (mlir::Operation::getName op) "slotraises.op") (set! found op))
             mlir::WalkResult::advance))
          (say "arguments: " (mlir::CallableOpInterface::getArgumentTypes found))
          (say "region is null: " (eqv? 0 (mlir::CallableOpInterface::getCallableRegion found))))))))
