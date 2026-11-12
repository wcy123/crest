;; Calls getCallableRegion, getFunctionType and setFunctionTypeAttr of ops of the ifaceclauses
;; dialect, and prints what each answers or leaves behind.
(import (chezscheme)
        (crest dialect)
        (mlir IR Operation)
        (mlir IR MLIRContext)
        (mlir IR OwningOpRef)
        (mlir IR DialectRegistry)
        (mlir IR Types)
        (mlir IR BuiltinAttributes)
        (only (mlir IR BuiltinTypes) mlir::IntegerType::get<i32> mlir::IntegerType::get<i64>
              mlir::FunctionType::get))

(define mlir::FunctionOpInterface::getFunctionType
  (foreign-procedure "mlir::FunctionOpInterface::getFunctionType" (uptr) uptr))
(define mlir::FunctionOpInterface::setFunctionTypeAttr
  (foreign-procedure "mlir::FunctionOpInterface::setFunctionTypeAttr" (uptr uptr) void))
(define mlir::CallableOpInterface::getCallableRegion
  (foreign-procedure "mlir::CallableOpInterface::getCallableRegion" (uptr) uptr))

(define (main)
  ;; LEAK WARNING: what this makes (the context, the module, the builder) lives in a with- scope and is
  ;; freed when the scope ends. A raw MLIRContext::new, ModuleOp::create or parseSourceFile result that is
  ;; never freed leaked, and exit inside a scope skips the cleanup: raise, and exit at the top (%%quit).
  (let ([args (command-line-arguments)])
    (when (null? args)
      (display "Usage: scheme-mlir passes/interface-slots.sls <file.mlir>\n"
               (current-error-port))
      (%%quit 1))
    (let* ()
      (with-DialectRegistry reg ()
        (with-MLIRContext ctx (reg)
          (mlir::MLIRContext::allowUnregisteredDialects ctx #t)
          (load-scheme-dialect! ctx "ifaceclauses" "passes/ifaceclauses")
          (with-mlir::OwningOpRef module (mlir::parseSourceFile ctx (car args))
            (when (zero? module)
              (display (string-append "Failed to parse: " (car args) "\n") (current-error-port))
              (%%quit 1))
            (with-current-MLIRContext ctx
              (let* ([find     (lambda (name)
                                 (let ([found #f])
                                   (mlir::Operation::walk
                                    module
                                    (lambda (op)
                                      (when (equal? (mlir::Operation::getName op) name)
                                        (set! found op))
                                      #t))
                                   found))]
                     [good     (find "ifaceclauses.good")]
                     [settable (find "ifaceclauses.settable")]
                     [bad      (find "ifaceclauses.bad")]
                     [new-type (mlir::TypeAttr::get
                                (mlir::FunctionType::get ctx
                                                         (list (mlir::IntegerType::get<i32>))
                                                         (list (mlir::IntegerType::get<i64>))))]
                     [type-of  (lambda (op)
                                 (mlir::Type::print
                                  (mlir::TypeAttr::getValue (mlir::Operation::getAttr op "function_type"))))])
                (let ([region (mlir::CallableOpInterface::getCallableRegion good)])
                  (display "callable region is region 0: ")
                  (display (if (= region (mlir::Operation::getRegion good 0)) 'true 'false))
                  (newline))
                (let ([type (mlir::FunctionOpInterface::getFunctionType good)])
                  (display "function type: ")
                  (display (mlir::Type::print type))
                  (newline))
                (mlir::FunctionOpInterface::setFunctionTypeAttr settable new-type)
                (display "type after set (clause): ")
                (display (type-of settable))
                (newline)
                (mlir::FunctionOpInterface::setFunctionTypeAttr bad new-type)
                (display "type after set (plain): ")
                (display (type-of bad))
                (newline)))))))))

;; A failure raises instead of calling exit: exit does not run the cleanup of the scopes around it.
(define (%%quit code)
  (raise (list 'exit code)))

(guard (e [(and (pair? e) (eq? (car e) 'exit)) (exit (cadr e))])
  (main))
