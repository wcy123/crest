#!r6rs
;; Unit test for the :interfaces DSL.
;;
;; NOTE: Interface method foreign-procedures must be defined locally in the
;; library that uses them. Chez Scheme's compiler crashes when imported
;; foreign-procedure bindings are referenced in compiled code (a Chez Scheme
;; compiler bug with cross-module foreign-procedure binding references).
;; Defining them locally with canonical names is the correct workaround.
(library (passes interface-dsl)
  (export run-pass)
  (import (chezscheme)
          (crest dialect)
          (crest dialect ffi)
          (mlir IR Operation)
          (mlir IR Region)
          (mlir IR Block)
          (mlir IR MLIRContext)
          (only (mlir Interfaces FunctionInterfaces) mlir::FunctionOpInterface)
          (only (mlir IR SymbolInterfaces) mlir::SymbolOpInterface)
          (only (mlir Interfaces CallInterfaces) mlir::CallableOpInterface))

  ;; Local foreign-procedure definitions with canonical names.
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

  (define-dialect ifacetest
    (define-op func
      :interfaces ((mlir::FunctionOpInterface))))

  (define (run-pass module)
    (let ([ctx (mlir::Operation::getContext module)])
      (with-current-MLIRContext ctx
        (ifacetest:register! ctx)
        (%crest::register-interface! "mlir::FunctionOpInterface"
                                     %%ifacetest.func:mlir::FunctionOpInterface)
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
    module))
