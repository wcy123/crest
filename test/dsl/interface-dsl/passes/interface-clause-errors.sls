;; Calls the verifiers of an op whose clauses raise a Scheme error.
(import (chezscheme)
        (passes ifaceclauses)
        (mlir IR Operation)
        (mlir IR Region)
        (mlir IR Block)
        (mlir IR MLIRContext))

(define mlir::FunctionOpInterface::verifyBody
  (foreign-procedure "mlir::FunctionOpInterface::verifyBody" (uptr) boolean))
(define mlir::FunctionOpInterface::verifyType
  (foreign-procedure "mlir::FunctionOpInterface::verifyType" (uptr) boolean))

(define (show label b)
  (display label)
  (display ": ")
  (display (if b 'true 'false))
  (newline))

(define (main)
  ;; Chez runs a library only when the program uses one of its exports.
  (unless (vector? ifaceclauses) (exit 1))
  (let* ([ctx (mlir::MLIRContext::new)]
         [_   (mlir::MLIRContext::allowUnregisteredDialects ctx #t)]
         [module (mlir::parseSourceFile ctx (car (command-line-arguments)))])
    (when (zero? module)
      (exit 1))
    (with-current-MLIRContext ctx
      (let ([op (mlir::Block::front (mlir::Region::front (mlir::Operation::getRegion module 0)))])
        (show "raises verifyBody" (mlir::FunctionOpInterface::verifyBody op))
        (show "raises verifyType" (mlir::FunctionOpInterface::verifyType op))
        (display "still running\n")))))

(main)
