;; Calls the interface methods of ops whose :interfaces entries have method clauses.
(import (chezscheme)
        (crest dialect)
        (mlir IR Operation)
        (mlir IR Region)
        (mlir IR Block)
        (mlir IR MLIRContext)
        (mlir IR Types)
        (only (mlir IR BuiltinTypes) mlir::IntegerType::get<i32> mlir::IntegerType::get<i64>
              mlir::Float32Type::get)
        (only (mlir Interfaces FunctionInterfaces) mlir::FunctionOpInterface::cloneTypeWith))

(define mlir::FunctionOpInterface::getFunctionType
  (foreign-procedure "mlir::FunctionOpInterface::getFunctionType" (uptr) uptr))
(define mlir::FunctionOpInterface::verifyBody
  (foreign-procedure "mlir::FunctionOpInterface::verifyBody" (uptr) boolean))
(define mlir::FunctionOpInterface::verifyType
  (foreign-procedure "mlir::FunctionOpInterface::verifyType" (uptr) boolean))
(define mlir::CallableOpInterface::getCallableRegion
  (foreign-procedure "mlir::CallableOpInterface::getCallableRegion" (uptr) uptr))

(define (show label b)
  (display label)
  (display ": ")
  (display (if b 'true 'false))
  (newline))

(define (main)
  (let ([args (command-line-arguments)])
    (when (null? args)
      (display "Usage: scheme-mlir passes/interface-clauses.sls <file.mlir>\n"
               (current-error-port))
      (exit 1))
    (let* ([ctx (mlir::MLIRContext::new)]
           [_   (mlir::MLIRContext::allowUnregisteredDialects ctx #t)]
           ;; The interfaces of an op are part of its definition: load the dialect.
           [_   (load-scheme-dialect! ctx "ifaceclauses" "passes/ifaceclauses")]
           [module (mlir::parseSourceFile ctx (car args))])
      (when (zero? module)
        (display (string-append "Failed to parse: " (car args) "\n") (current-error-port))
        (exit 1))
      (with-current-MLIRContext ctx
        (let* ([block (mlir::Region::front (mlir::Operation::getRegion module 0))]
               [good  (mlir::Block::front block)]
               [bad   (mlir::Block::back block)])
          (show "getFunctionType" (not (zero? (mlir::FunctionOpInterface::getFunctionType good))))
          (show "verifyBody" (mlir::FunctionOpInterface::verifyBody good))
          (show "verifyType" (mlir::FunctionOpInterface::verifyType good))
          (show "getCallableRegion"
                (not (zero? (mlir::CallableOpInterface::getCallableRegion good))))
          (show "bad verifyBody" (mlir::FunctionOpInterface::verifyBody bad))
          (show "bad verifyType" (mlir::FunctionOpInterface::verifyType bad))
          ;; cloneTypeWith: the clause of `good` reverses the inputs, `bad` has the default.
          (let* ([inputs    (list (mlir::IntegerType::get<i32>) (mlir::Float32Type::get))]
                 [results   (list (mlir::IntegerType::get<i64>))]
                 [good-type (mlir::FunctionOpInterface::cloneTypeWith good inputs results)]
                 [bad-type  (mlir::FunctionOpInterface::cloneTypeWith bad inputs results)])
            (display "good cloneTypeWith: ")
            (display (mlir::Type::print good-type))
            (newline)
            (display "bad cloneTypeWith: ")
            (display (mlir::Type::print bad-type))
            (newline)))))))

(main)
