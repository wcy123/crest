;; Calls verifyBody, verifyType and cloneTypeWith on function ops that give none of them.
(import (chezscheme)
        (crest dialect)
        (mlir IR Operation)
        (mlir IR MLIRContext)
        (mlir IR OwningOpRef)
        (mlir IR DialectRegistry)
        (mlir IR Types)
        (only (mlir IR BuiltinTypes) mlir::IntegerType::get<i64> mlir::Float32Type::get)
        (only (mlir Interfaces FunctionInterfaces)
              mlir::FunctionOpInterface::verifyBody
              mlir::FunctionOpInterface::verifyType
              mlir::FunctionOpInterface::cloneTypeWith))

(define (say . parts) (for-each display parts) (newline) (flush-output-port (current-output-port)))

(define (main)
  (let* ([args (command-line-arguments)])
    (with-DialectRegistry reg ()
      (with-MLIRContext ctx (reg)
        (mlir::MLIRContext::allowUnregisteredDialects ctx #t)
        (load-scheme-dialect! ctx "fdefaults" "passes/fdefaults")
        (with-mlir::OwningOpRef module (mlir::parseSourceFile ctx (car args))
          (when (zero? module)
            (display "Failed to parse\n" (current-error-port))
            (%%quit 1))
          (with-current-MLIRContext ctx
            (let ([ops '()])
              (mlir::Operation::walk
               module
               (lambda (op)
                 (when (equal? (mlir::Operation::getName op) "fdefaults.fn")
                   (set! ops (cons op ops)))
                 #t))
              (for-each
               (lambda (op)
                 (let ([name (mlir::Operation::getAttr op "sym_name")])
                   (say (mlir::Operation::getName op) " verifyBody: "
                        (if (mlir::FunctionOpInterface::verifyBody op) 'true 'false))))
               (reverse ops))
              (let ([op (car ops)])
                (say "verifyType: " (if (mlir::FunctionOpInterface::verifyType op) 'true 'false))
                (say "cloneTypeWith: "
                     (mlir::Type::print
                      (mlir::FunctionOpInterface::cloneTypeWith
                       op (list (mlir::Float32Type::get)) (list (mlir::IntegerType::get<i64>)))))))))))))

;; A failure raises instead of calling exit: exit does not run the cleanup of the scopes around it.
(define (%%quit code)
  (raise (list 'exit code)))

(guard (e [(and (pair? e) (eq? (car e) 'exit)) (exit (cadr e))])
  (main))
