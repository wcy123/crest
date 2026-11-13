;; Unit test for the :interfaces DSL — top-level program for scheme-mlir.
(import (only (crest pass) define-pass-entry-point)
        (chezscheme)
        (mlir support foreign)
        (crest dialect)
        (mlir IR Operation)
        (mlir IR Region)
        (mlir IR Block)
        (mlir IR MLIRContext)
        (mlir IR OwningOpRef)
        (mlir IR DialectRegistry))

(define mlir::FunctionOpInterface::getFunctionType
  (crest-foreign-procedure "mlir::FunctionOpInterface::getFunctionType" (uptr) uptr))
(define mlir::FunctionOpInterface::verifyBody
  (crest-foreign-procedure "mlir::FunctionOpInterface::verifyBody" (uptr) boolean))
(define mlir::FunctionOpInterface::verifyType
  (crest-foreign-procedure "mlir::FunctionOpInterface::verifyType" (uptr) boolean))
(define mlir::CallableOpInterface::getCallableRegion
  (crest-foreign-procedure "mlir::CallableOpInterface::getCallableRegion" (uptr) uptr))
(define mlir::SymbolOpInterface::getNameAttr
  (crest-foreign-procedure "mlir::SymbolOpInterface::getNameAttr" (uptr) uptr))

(define (main)
  ;; LEAK WARNING: what this makes (the context, the module, the builder) lives in a with- scope and is
  ;; freed when the scope ends. A raw MLIRContext::new, ModuleOp::create or parseSourceFile result that is
  ;; never freed leaked, and exit inside a scope skips the cleanup: raise, and exit at the top (%%quit).
  (let ([args (command-line-arguments)])
    (when (null? args)
      (display "Usage: scheme-mlir passes/interface-dsl.sls <file.mlir>\n"
               (current-error-port))
      (%%quit 1))
    ;; The interfaces of an op are part of its definition, so they exist in a context that loads the
    ;; dialect.
    (let* ()
      (with-DialectRegistry reg ()
        (with-MLIRContext ctx (reg)
          (mlir::MLIRContext::allowUnregisteredDialects ctx #t)
          (load-scheme-dialect! ctx "ifacetest" "passes/ifacetest")
          (with-mlir::OwningOpRef op (mlir::parseSourceFile ctx (car args))
            (when (zero? op)
              (display (string-append "Failed to parse: " (car args) "\n")
                       (current-error-port))
              (%%quit 1))
            (pass-entry-point op)
            (display (mlir::Operation::print op))
            (newline)))))))

(define-pass-entry-point (module)
  (let ([ctx (mlir::Operation::getContext module)])
    (with-current-MLIRContext ctx
      (let* ([body-region (mlir::Operation::getRegion module 0)]
             [body-block  (mlir::Region::front body-region)]
             [func-op     (mlir::Block::front body-block)])
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

;; A failure raises instead of calling exit: exit does not run the cleanup of the scopes around it.
(define (%%quit code)
  (raise (list 'exit code)))

(guard (e [(and (pair? e) (eq? (car e) 'exit)) (exit (cadr e))])
  (main))
