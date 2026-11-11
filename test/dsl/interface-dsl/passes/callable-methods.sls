;; Calls the three methods of CallableOpInterface on the ops of the callablemethods dialect.
(import (chezscheme)
        (crest dialect)
        (mlir IR Operation)
        (mlir IR MLIRContext)
        (mlir IR Types)
        (only (mlir Interfaces CallInterfaces)
              mlir::CallableOpInterface::getCallableRegion
              mlir::CallableOpInterface::getArgumentTypes
              mlir::CallableOpInterface::getResultTypes))

(define (say . parts) (for-each display parts) (newline))

(define (types->string types)
  (map mlir::Type::print types))

(define (main)
  (let* ([args (command-line-arguments)]
         [ctx (mlir::MLIRContext::new)]
         [_   (mlir::MLIRContext::allowUnregisteredDialects ctx #t)]
         [_   (load-scheme-dialect! ctx "callablemethods" "passes/callablemethods")]
         [module (mlir::parseSourceFile ctx (car args))])
    (when (zero? module)
      (display "Failed to parse\n" (current-error-port))
      (exit 1))
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
         '("one" "two"))))))

(main)
