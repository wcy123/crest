;; Calls the three methods of CallableOpInterface on the ops of the callablemethods dialect.
(import (chezscheme)
        (crest dialect)
        (mlir IR Operation)
        (mlir IR MLIRContext)
        (mlir IR OwningOpRef)
        (mlir IR DialectRegistry)
        (mlir IR Types)
        (only (mlir Interfaces CallInterfaces)
              mlir::CallableOpInterface::getCallableRegion
              mlir::CallableOpInterface::getArgumentTypes
              mlir::CallableOpInterface::getResultTypes))

(define (say . parts) (for-each display parts) (newline))

(define (types->string types)
  (map mlir::Type::print types))

(define (main)
  ;; LEAK WARNING: what this makes (the context, the module, the builder) lives in a with- scope and is
  ;; freed when the scope ends. A raw MLIRContext::new, ModuleOp::create or parseSourceFile result that is
  ;; never freed leaked, and exit inside a scope skips the cleanup: raise, and exit at the top (%%quit).
  (let* ([args (command-line-arguments)])
    (with-DialectRegistry reg ()
      (with-MLIRContext ctx (reg)
        (mlir::MLIRContext::allowUnregisteredDialects ctx #t)
        (load-scheme-dialect! ctx "callablemethods" "passes/callablemethods")
        (with-mlir::OwningOpRef module (mlir::parseSourceFile ctx (car args))
          (when (zero? module)
            (display "Failed to parse\n" (current-error-port))
            (%%quit 1))
          (with-current-MLIRContext ctx
            (let ([find (lambda (name)
                          (let ([found #f])
                            (mlir::Operation::walk
                             module
                             (lambda (op)
                               (when (equal? (mlir::Operation::getName op)
                                             (string-append "callablemethods." name))
                                 (set! found op))
                               #t))
                            found))])
              (for-each
               (lambda (name)
                 (let* ([op     (find name)]
                        [region (mlir::CallableOpInterface::getCallableRegion op)]
                        [index  (if (= region (mlir::Operation::getRegion op 0)) 0 1)])
                   (say name " region: " index)
                   (say name " arguments: " (types->string (mlir::CallableOpInterface::getArgumentTypes op)))
                   (say name " results: " (types->string (mlir::CallableOpInterface::getResultTypes op)))))
               '("one" "two")))))))))

;; A failure raises instead of calling exit: exit does not run the cleanup of the scopes around it.
(define (%%quit code)
  (raise (list 'exit code)))

(guard (e [(and (pair? e) (eq? (car e) 'exit)) (exit (cadr e))])
  (main))
