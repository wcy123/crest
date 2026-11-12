;; Calls the verifiers of an op whose clauses raise a Scheme error.
(import (chezscheme)
        (mlir support foreign)
        (crest dialect)
        (mlir IR Operation)
        (mlir IR Region)
        (mlir IR Block)
        (mlir IR MLIRContext)
        (mlir IR OwningOpRef)
        (mlir IR DialectRegistry))

(define mlir::FunctionOpInterface::verifyBody
  (crest-foreign-procedure "mlir::FunctionOpInterface::verifyBody" (uptr) boolean))
(define mlir::FunctionOpInterface::verifyType
  (crest-foreign-procedure "mlir::FunctionOpInterface::verifyType" (uptr) boolean))

(define (show label b)
  (display label)
  (display ": ")
  (display (if b 'true 'false))
  (newline))

(define (main)
  (let* ()
    ;; LEAK WARNING: what this makes (the context, the module, the builder) lives in a with- scope and is
    ;; freed when the scope ends. A raw MLIRContext::new, ModuleOp::create or parseSourceFile result that is
    ;; never freed leaked, and exit inside a scope skips the cleanup: raise, and exit at the top (%%quit).
    (with-DialectRegistry reg ()
      (with-MLIRContext ctx (reg)
        (mlir::MLIRContext::allowUnregisteredDialects ctx #t)
        (load-scheme-dialect! ctx "ifaceclauses" "passes/ifaceclauses")
        (with-mlir::OwningOpRef module (mlir::parseSourceFile ctx (car (command-line-arguments)))
          (when (zero? module)
            (%%quit 1))
          (with-current-MLIRContext ctx
            (let ([op (mlir::Block::front (mlir::Region::front (mlir::Operation::getRegion module 0)))])
              (show "raises verifyBody" (mlir::FunctionOpInterface::verifyBody op))
              (show "raises verifyType" (mlir::FunctionOpInterface::verifyType op))
              (display "still running\n"))))))))

;; A failure raises instead of calling exit: exit does not run the cleanup of the scopes around it.
(define (%%quit code)
  (raise (list 'exit code)))

(guard (e [(and (pair? e) (eq? (car e) 'exit)) (exit (cadr e))])
  (main))
