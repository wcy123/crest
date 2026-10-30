;; Unit test for the :interfaces DSL — top-level program for scheme-mlir.
(import (chezscheme)
        (passes ifacetest)
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
(define mlir::SymbolOpInterface::getNameAttr
  (foreign-procedure "mlir::SymbolOpInterface::getNameAttr" (uptr) uptr))

(define (main)
  (let ([args (command-line-arguments)])
    (when (null? args)
      (display "Usage: scheme-mlir passes/interface-dsl.sls <file.mlir>\n"
               (current-error-port))
      (exit 1))
    (let* ([ctx (mlir::MLIRContext::new)]
           [_   (mlir::MLIRContext::allowUnregisteredDialects ctx #t)]
           [op  (mlir::parseSourceFile ctx (car args))])
      (when (zero? op)
        (display (string-append "Failed to parse: " (car args) "\n")
                 (current-error-port))
        (exit 1))
      (run-pass op)
      (display (mlir::Operation::print op))
      (newline))))

(define (run-pass module)
  (let ([ctx (mlir::Operation::getContext module)])
    (with-current-MLIRContext ctx
      (let* ([body-region (mlir::Operation::getRegion module 0)]
             [body-block  (mlir::Region::front body-region)]
             [func-op     (mlir::Block::front body-block)])
        (display "dispatcher-op-name: ")
        (display (%%ifacetest.func:mlir::FunctionOpInterface 'operation_name)) (newline)
        (display "dispatcher-getFunctionType: ")
        (display (%%ifacetest.func:mlir::FunctionOpInterface 'getFunctionType)) (newline)
        (display "dispatcher-verifyBody: ")
        (display (%%ifacetest.func:mlir::FunctionOpInterface 'verifyBody)) (newline)
        (display "getFunctionType: ")
        (display (not (zero? (mlir::FunctionOpInterface::getFunctionType func-op)))) (newline)
        (display "verifyBody: ")
        (display (if (mlir::FunctionOpInterface::verifyBody func-op) #t #f)) (newline)
        (display "verifyType: ")
        (display (if (mlir::FunctionOpInterface::verifyType func-op) #t #f)) (newline)
        (display "getCallableRegion: ")
        (display (if (zero? (mlir::CallableOpInterface::getCallableRegion func-op)) 'null 'non-null)) (newline)
        (display "getNameAttr: ")
        (display (if (zero? (mlir::SymbolOpInterface::getNameAttr func-op)) 'null 'non-null)) (newline))))
  module)

(main)
