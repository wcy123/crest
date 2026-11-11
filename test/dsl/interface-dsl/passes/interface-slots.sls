;; Calls getCallableRegion, getFunctionType and setFunctionTypeAttr of ops of the ifaceclauses
;; dialect, and prints what each answers or leaves behind.
(import (chezscheme)
        (crest dialect)
        (mlir IR Operation)
        (mlir IR MLIRContext)
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
  (let ([args (command-line-arguments)])
    (when (null? args)
      (display "Usage: scheme-mlir passes/interface-slots.sls <file.mlir>\n"
               (current-error-port))
      (exit 1))
    (let* ([ctx (mlir::MLIRContext::new)]
           [_   (mlir::MLIRContext::allowUnregisteredDialects ctx #t)]
           [_   (load-scheme-dialect! ctx "ifaceclauses" "passes/ifaceclauses")]
           [module (mlir::parseSourceFile ctx (car args))])
      (when (zero? module)
        (display (string-append "Failed to parse: " (car args) "\n") (current-error-port))
        (exit 1))
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
          (display "type after set (default): ")
          (display (type-of bad))
          (newline))))))

(main)
