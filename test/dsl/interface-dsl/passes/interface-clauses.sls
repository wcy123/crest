;; Calls the interface methods of ops whose :interfaces entries have method clauses.
(import (chezscheme)
        (passes ifaceclauses)
        (mlir IR Operation)
        (mlir IR Region)
        (mlir IR Block)
        (mlir IR MLIRContext))

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
  ;; Chez runs a library only when the program uses one of its exports; the interface concepts of
  ;; the ops are registered when (passes ifaceclauses) runs.
  (unless (vector? ifaceclauses) (exit 1))
  (let ([args (command-line-arguments)])
    (when (null? args)
      (display "Usage: scheme-mlir passes/interface-clauses.sls <file.mlir>\n"
               (current-error-port))
      (exit 1))
    (let* ([ctx (mlir::MLIRContext::new)]
           [_   (mlir::MLIRContext::allowUnregisteredDialects ctx #t)]
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
          (show "bad verifyType" (mlir::FunctionOpInterface::verifyType bad)))))))

(main)
