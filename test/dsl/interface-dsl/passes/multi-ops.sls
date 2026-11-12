;; Calls the interface methods of every op of the multiops dialect and prints what each answers.
(import (chezscheme)
        (crest dialect)
        (mlir IR Operation)
        (mlir IR MLIRContext)
        (mlir IR OwningOpRef)
        (mlir IR DialectRegistry)
        (mlir IR Types)
        (mlir IR BuiltinAttributes)
        (only (mlir IR BuiltinTypes) mlir::FunctionType::get mlir::IntegerType::get<i32>))

(define mlir::FunctionOpInterface::getFunctionType
  (foreign-procedure "mlir::FunctionOpInterface::getFunctionType" (uptr) uptr))
(define mlir::FunctionOpInterface::setFunctionTypeAttr
  (foreign-procedure "mlir::FunctionOpInterface::setFunctionTypeAttr" (uptr uptr) void))
(define mlir::FunctionOpInterface::verifyBody
  (foreign-procedure "mlir::FunctionOpInterface::verifyBody" (uptr) boolean))
(define mlir::CallableOpInterface::getCallableRegion
  (foreign-procedure "mlir::CallableOpInterface::getCallableRegion" (uptr) uptr))

(define (say . parts) (for-each display parts) (newline))

(define (main)
  (let* ([args (command-line-arguments)])
    (with-DialectRegistry reg ()
      (with-MLIRContext ctx (reg)
        (mlir::MLIRContext::allowUnregisteredDialects ctx #t)
        (load-scheme-dialect! ctx "multiops" "passes/multiops")
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
                               (when (equal? (mlir::Operation::getName op) (string-append "multiops." name))
                                 (set! found op))
                               #t))
                            found))])
              (for-each
               (lambda (name)
                 (let* ([op     (find name)]
                        [region (mlir::CallableOpInterface::getCallableRegion op)]
                        [index  (let lp ([i 0])
                                  (cond [(= i 3) 'none]
                                        [(= region (mlir::Operation::getRegion op i)) i]
                                        [else (lp (+ i 1))]))])
                   (say name ": region " index)))
               '("first" "second" "third" "plain"))
              (for-each
               (lambda (name)
                 (say name " type: "
                      (mlir::Type::print (mlir::FunctionOpInterface::getFunctionType (find name)))))
               '("fn-a" "fn-b" "fn-c"))
              (for-each
               (lambda (name)
                 (say name " verifyBody: "
                      (if (mlir::FunctionOpInterface::verifyBody (find name)) 'true 'false)))
               '("fn-a" "fn-b" "fn-c"))
              (let ([attr (mlir::TypeAttr::get
                           (mlir::FunctionType::get ctx (list (mlir::IntegerType::get<i32>)) '()))])
                (for-each
                 (lambda (name)
                   (let ([op (find name)])
                     (mlir::FunctionOpInterface::setFunctionTypeAttr op attr)
                     (let ([has (lambda (n) (if (mlir::Operation::getAttr op n) 'true 'false))])
                       (say name " set: set_by_a=" (has "set_by_a") " set_by_b=" (has "set_by_b")))))
                 '("fn-a" "fn-b"))))))))))

;; A failure raises instead of calling exit: exit does not run the cleanup of the scopes around it.
(define (%%quit code)
  (raise (list 'exit code)))

(guard (e [(and (pair? e) (eq? (car e) 'exit)) (exit (cadr e))])
  (main))
